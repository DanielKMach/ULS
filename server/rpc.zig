const std = @import("std");
const log = std.log.scoped(.rpc);

pub const parse_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
};
pub const emit_opts: std.json.Stringify.Options = .{};

pub fn sendMsg(payload: anytype, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    const formatter = std.json.fmt(payload, .{});
    const count = std.fmt.count("{f}", .{formatter});

    try writer.print("Content-Length: {d}\r\n", .{count});
    try writer.writeAll("\r\n");

    try writer.print("{f}", .{formatter});
    log.info("Enviado: {f}", .{formatter});
}

pub fn receiveMsg(reader: *std.Io.Reader, allocator: std.mem.Allocator) ![]u8 {
    var length: usize = 0;
    while (true) {
        const line = std.mem.trim(u8, try reader.takeDelimiterInclusive('\n'), "\r\n");

        if (line.len == 0) break;
        if (std.mem.startsWith(u8, line, "Content-Length: ")) {
            length = try std.fmt.parseInt(usize, line[16..], 10);
        }
    }

    return try reader.readAlloc(allocator, length);
}

test sendMsg {
    var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer.deinit();

    try sendMsg(.{
        .name = "Test",
        .age = 26,
        .active = true,
        .data = .{
            .foo = 123,
            .bar = "hello",
            .baz = .{ true, false, null },
        },
    }, &writer.writer);

    try std.testing.expectEqualStrings("Content-Length: 95\r\n\r\n{\"name\":\"Test\",\"age\":26,\"active\":true,\"data\":{\"foo\":123,\"bar\":\"hello\",\"baz\":[true,false,null]}}", writer.written());
}

test receiveMsg {
    const buf = "Content-Length: 41\r\n\r\n{\"method\": \"example/example\", \"foo\": 123}";
    var reader = std.Io.Reader.fixed(buf);

    const content = try receiveMsg(&reader, std.testing.allocator);
    defer std.testing.allocator.free(content);

    try std.testing.expectEqual(41, content.len);
    try std.testing.expectEqualStrings("{\"method\": \"example/example\", \"foo\": 123}", content);
}
