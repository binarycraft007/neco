const std = @import("std");
const posix = std.posix;
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const root = @import("root");
pub const c = @cImport({
    @cInclude("neco.h");
});
const testing = std.testing;

pub fn startMain() void {
    c.neco_env_setpaniconerror(true);
    c.neco_env_setcanceltype(c.NECO_CANCEL_ASYNC);
    const ret = c.neco_start(struct {
        fn _neco_main(
            argc: c_int,
            argv: [*c]?*anyopaque,
        ) callconv(.C) void {
            _ = argc;
            _ = argv;
            c.__neco_exit_prog(callFn(root.necoMain, .{}));
        }
    }._neco_main, 0);
    std.debug.assert(ret == 0);
}

pub fn spawn(comptime f: anytype, args: anytype) !void {
    const Args = @TypeOf(args);
    const ret = c.neco_start(struct {
        fn _neco_main(
            argc: c_int,
            argv: [*c]?*anyopaque,
        ) callconv(.C) void {
            std.debug.assert(argc == 1);
            const _args_ptr: *Args = @ptrCast(@alignCast(argv[0]));
            _ = callFn(f, _args_ptr.*);
        }
    }._neco_main, 1, &args);
    std.debug.assert(ret == 0);
}

pub const AcceptError = error{
    ConnectionAborted,

    /// The file descriptor sockfd does not refer to a socket.
    FileDescriptorNotASocket,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Not enough free memory.  This often means that the memory allocation  is  limited
    /// by the socket buffer limits, not by the system memory.
    SystemResources,

    /// Socket is not listening for new connections.
    SocketNotListening,

    ProtocolFailure,

    /// Firewall rules forbid connection.
    BlockedByFirewall,

    /// An incoming connection was indicated, but was subsequently terminated by the
    /// remote peer prior to accepting the call.
    ConnectionResetByPeer,

    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    /// The referenced socket is not a type that supports connection-oriented service.
    OperationNotSupported,
} || posix.UnexpectedError;

pub fn accept(
    sock: posix.socket_t,
    addr: ?*posix.sockaddr,
    addr_size: ?*posix.socklen_t,
) AcceptError!posix.socket_t {
    const rc = c.neco_accept(sock, @ptrCast(addr), @ptrCast(addr_size));
    switch (posix.errno(rc)) {
        .SUCCESS => return switch (native_os) {
            .windows => @ptrFromInt(@as(usize, @intCast(c._get_osfhandle(rc)))),
            else => rc,
        },
        .INTR => unreachable,
        .AGAIN => unreachable,
        .BADF => unreachable, // always a race condition
        .CONNABORTED => return error.ConnectionAborted,
        .FAULT => unreachable,
        .INVAL => return error.SocketNotListening,
        .NOTSOCK => unreachable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOBUFS => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        .OPNOTSUPP => unreachable,
        .PROTO => return error.ProtocolFailure,
        .PERM => return error.BlockedByFirewall,
        else => |err| return posix.unexpectedErrno(err),
    }
}

pub const ReadError = error{
    InputOutput,
    SystemResources,
    IsDir,
    OperationAborted,
    BrokenPipe,
    ConnectionResetByPeer,
    ConnectionTimedOut,
    NotOpenForReading,
    SocketNotConnected,

    /// In WASI, this error occurs when the file descriptor does
    /// not hold the required rights to read from it.
    AccessDenied,
} || posix.UnexpectedError;

pub fn read(fd: posix.fd_t, buf: []u8) ReadError!usize {
    if (buf.len == 0) return 0;
    // Prevents EINVAL.
    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => std.math.maxInt(i32),
        else => std.math.maxInt(isize),
    };
    const rc = c.neco_read(fd, buf.ptr, @min(buf.len, max_count));
    switch (posix.errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .INTR => unreachable,
        .INVAL => unreachable,
        .FAULT => unreachable,
        .AGAIN => unreachable,
        .BADF => return error.NotOpenForReading, // Can be a race condition.
        .IO => return error.InputOutput,
        .ISDIR => return error.IsDir,
        .NOBUFS => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        .NOTCONN => return error.SocketNotConnected,
        .CONNRESET => return error.ConnectionResetByPeer,
        .TIMEDOUT => return error.ConnectionTimedOut,
        else => |err| return posix.unexpectedErrno(err),
    }
}

pub const WriteError = error{
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    DeviceBusy,
    InvalidArgument,

    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to write to it.
    AccessDenied,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    NotOpenForWriting,

    /// The process cannot access the file because another process has locked
    /// a portion of the file. Windows-only.
    LockViolation,

    /// This error occurs when no global event loop is configured,
    /// and reading from the file descriptor would block.
    WouldBlock,

    /// Connection reset by peer.
    ConnectionResetByPeer,
} || posix.UnexpectedError;

pub fn write(fd: posix.fd_t, bytes: []const u8) WriteError!usize {
    if (bytes.len == 0) return 0;

    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => posix.maxInt(i32),
        else => posix.maxInt(isize),
    };
    const rc = c.neco_write(fd, bytes.ptr, @min(bytes.len, max_count));
    switch (posix.errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .INTR => unreachable,
        .INVAL => return error.InvalidArgument,
        .FAULT => unreachable,
        .AGAIN => unreachable,
        .BADF => return error.NotOpenForWriting, // can be a race condition.
        .DESTADDRREQ => unreachable, // `connect` was never called.
        .DQUOT => return error.DiskQuota,
        .FBIG => return error.FileTooBig,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .PERM => return error.AccessDenied,
        .PIPE => return error.BrokenPipe,
        .CONNRESET => return error.ConnectionResetByPeer,
        .BUSY => return error.DeviceBusy,
        else => |err| return posix.unexpectedErrno(err),
    }
}

fn callFn(comptime f: anytype, args: anytype) c_int {
    const default_ret: c_int = 0;
    const bad_fn_ret = "expected return type of startFn to be " ++
        "'noreturn', '!noreturn', 'void', or '!void'";
    switch (@typeInfo(@typeInfo(@TypeOf(f)).Fn.return_type.?)) {
        .NoReturn => {
            @call(.auto, f, args);
            return default_ret;
        },
        .Void => {
            @call(.auto, f, args);
            return default_ret;
        },
        .ErrorUnion => |info| {
            switch (info.payload) {
                void, noreturn => {
                    @call(.auto, f, args) catch |err| {
                        std.debug.print("error: {s}\n", .{@errorName(err)});
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpStackTrace(trace.*);
                        }
                    };
                    return default_ret;
                },
                else => {
                    @compileError(bad_fn_ret);
                },
            }
        },
        else => {
            @compileError(bad_fn_ret);
        },
    }
}
