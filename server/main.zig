const std = @import("std");
const lsp = @import("lsp");
const log = std.log.default;

pub const ULS = @import("ULS.zig");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var buf: [1024]u8 = undefined;
    var stdio = lsp.Transport.Stdio.init(&buf, .stdin(), .stdout());

    var uls = ULS{
        .allocator = allocator,
        .docs = .init(allocator),
    };

    try lsp.basic_server.run(
        allocator,
        &stdio.transport,
        &uls,
        log.err,
    );
}

test {
    _ = std.testing.refAllDeclsRecursive(@This());
}
