const std = @import("std");
const log = std.log.default;

pub const rpc = @import("rpc.zig");
pub const ULS = @import("ULS.zig");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    const stdin = std.fs.File.stdin();
    const stdout = std.fs.File.stdout();

    var inbuf: [1 << 15]u8 = undefined;
    var outbuf: [1 << 15]u8 = undefined;
    var in = stdin.reader(&inbuf);
    var out = stdout.writer(&outbuf);

    var uls = ULS{
        .allocator = allocator,
        .docs = .init(allocator),
    };

    log.info("ULS Started", .{});
    while (rpc.receiveMsg(&in.interface, allocator)) |content| {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        try uls.handleMsg(content, &out.interface, arena.allocator());
        try out.interface.flush();
    } else |err| switch (err) {
        error.EndOfStream => log.info("Session terminated", .{}),
        else => {
            log.err("Error during main loop: {t}", .{err});
            return err;
        },
    }
}

test {
    _ = std.testing.refAllDeclsRecursive(@This());
}
