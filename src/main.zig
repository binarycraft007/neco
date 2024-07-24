const std = @import("std");
const neco = @import("root.zig");

pub fn main() !void {
    neco.startMain();
}

pub fn necoMain() !void {
    var listener = try std.net.Address.parseIp("127.0.0.1", 2080);
    var server = try listener.listen(.{
        .reuse_port = true,
        .reuse_address = true,
        .force_nonblocking = true,
    });
    defer server.deinit();
    std.debug.print("listening at 127.0.0.1:2080\n", .{});
    while (true) {
        const conn = try neco.accept(server.stream.handle, null, null);
        try neco.spawn(client, .{conn});
    }
    return 0;
}

fn client(conn: c_int) !void {
    std.debug.print("client connected\n", .{});
    defer std.posix.close(conn);
    var buf: [64]u8 = undefined;
    while (true) {
        const n = try neco.read(conn, &buf);
        if (n <= 0) {
            break;
        }
        std.debug.print("{s}\n", .{buf[0..@intCast(n)]});
    }
    std.debug.print("client disconnected\n", .{});
}
