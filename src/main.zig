const std = @import("std");
const neco = @import("root.zig");
const net = @import("net.zig");
const HttpServer = @import("Server.zig");

pub fn main() !void {
    neco.startMain();
}

pub fn necoMain() !void {
    var listener = try net.Address.parseIp("127.0.0.1", 19203);
    var server = try listener.listen(.{
        .reuse_port = true,
        .reuse_address = true,
        .force_nonblocking = true,
    });
    defer server.deinit();
    std.debug.print("listening at 127.0.0.1:19203\n", .{});
    while (true) {
        const conn = try server.accept();
        try neco.spawn(client, .{conn});
    }
    return 0;
}

fn client(conn: net.Server.Connection) !void {
    var header_buffer: [1024]u8 = undefined;
    var server = HttpServer.init(conn, &header_buffer);
    //defer conn.stream.close();
    while (server.state != .closing) {
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return, // situation normal
            else => |e| {
                std.log.err("connection failed: {s}", .{@errorName(e)});
                return;
            },
        };
        try serve(&request);
    }
}

fn serve(request: *HttpServer.Request) !void {
    var send_buffer: [1024]u8 = undefined;
    var response = request.respondStreaming(.{
        .send_buffer = &send_buffer,
    });
    if (std.mem.eql(u8, request.head.target, "/")) {
        try response.writeAll("Hello, ");
        try response.flush();
        try response.writeAll("World!\n");
        try response.flush();
        try response.endChunked(.{
            .trailers = &.{
                .{ .name = "X-Checksum", .value = "aaaa" },
            },
        });
    } else {
        try response.writeAll("404 ");
        try response.flush();
        try response.writeAll("NotFound\n");
        try response.flush();
        try response.endChunked(.{
            .trailers = &.{
                .{ .name = "X-Checksum", .value = "aaaa" },
            },
        });
    }
}
