const std = @import("std");
const c = @cImport(@cInclude("neco.h"));

pub fn main() !void {
    c.neco_env_setpaniconerror(true);
    c.neco_env_setcanceltype(c.NECO_CANCEL_ASYNC);
    const ret = c.neco_start(struct {
        fn _neco_main(
            argc: c_int,
            argv: [*c]?*anyopaque,
        ) callconv(.C) void {
            _ = argc;
            _ = argv;
            c.__neco_exit_prog(@call(.auto, necoMain, .{}));
        }
    }._neco_main, 0);
    std.debug.assert(ret == 0);
}

fn necoMain() callconv(.C) c_int {
    var listener = std.net.Address.parseIp("127.0.0.1", 2080) catch {
        return 0;
    };
    var server = listener.listen(.{
        .reuse_port = true,
        .reuse_address = true,
        .force_nonblocking = true,
    }) catch {
        return 0;
    };
    defer server.deinit();
    std.debug.print("listening at 127.0.0.1:2080\n", .{});
    while (true) {
        const conn = c.neco_accept(server.stream.handle, 0, 0);
        if (conn > 0) {
            _ = c.neco_start(client, 1, &conn);
        }
    }
    return 0;
}

fn client(argc: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    std.debug.assert(argc == 1);
    const conn: *c_int = @ptrCast(@alignCast(argv[0]));
    std.debug.print("client connected\n", .{});
    defer std.posix.close(conn.*);
    var buf: [64]u8 = undefined;
    while (true) {
        const n = c.neco_read(conn.*, &buf, buf.len);
        if (n <= 0) {
            break;
        }
        std.debug.print("{s}\n", .{buf[0..@intCast(n)]});
    }
    std.debug.print("client disconnected\n", .{});
}
