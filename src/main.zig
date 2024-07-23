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
    const ln = c.neco_serve("tcp", "127.0.0.1:2080");
    if (ln <= 0) {
        std.debug.print("neco_serve\n", .{});
        std.posix.exit(1);
    }
    defer std.posix.close(ln);
    std.debug.print("listening at 127.0.0.1:2080\n", .{});
    while (true) {
        const conn = c.neco_accept(ln, 0, 0);
        if (conn > 0) {
            _ = c.neco_start(client, 1, &conn);
        }
    }
    return 0;
}

fn client(argc: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    _ = argc;
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
