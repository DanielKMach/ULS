const std = @import("std");
const ULS = @import("../ULS.zig");
const doc = @import("doc.zig");

pub const CodeLensRequest = struct {
    pub const method = "textDocument/codeLens";

    id: isize,
    params: struct {
        textDocument: doc.TextDocumentIdentifier,
    },

    pub fn handle(uls: *ULS, request: @This(), allocator: std.mem.Allocator) ULS.Error!Response {
        const query = (uls.docs.get(request.params.textDocument.uri) orelse {
            return error.DocumentNotFound;
        }).content;

        var lenses = std.ArrayList(CodeLens([]const u8)).empty;
        defer lenses.deinit(allocator);

        var parsing = false;
        var indent: usize = 0;
        var starti: usize = 0;
        var start: doc.Position = .{ .line = 0, .character = 0 };
        var pos: doc.Position = .{ .line = 0, .character = 0 };
        var iterator = std.unicode.Utf8Iterator{ .bytes = query, .i = 0 };
        while (iterator.nextCodepoint()) |cp| {
            defer if (cp == '\n') {
                pos.line += 1;
                pos.character = 0;
            } else {
                pos.character += 1;
            };

            if (!parsing) {
                if (cp < 128 and std.ascii.isWhitespace(@intCast(cp)))
                    continue;
                const cp_len = std.unicode.utf8CodepointSequenceLength(cp) catch unreachable;
                starti = iterator.i - cp_len;
                start = pos;
                parsing = true;
            }

            switch (cp) {
                '{' => indent += 1,
                '}' => indent -= @min(indent, 1),
                ';' => {
                    if (!parsing or indent != 0) continue;
                    const args = try allocator.alloc([]u8, 1);
                    args[0] = try allocator.dupe(u8, query[starti..iterator.i]);
                    try lenses.append(allocator, .{
                        .range = .{ .start = start, .end = pos },
                        .command = .{
                            .title = "Run Query",
                            .command = "usrlLanguageServer.runQuery",
                            .arguments = args,
                        },
                    });
                    parsing = false;
                },
                else => continue,
            }
        }
        if (parsing) {
            const args = try allocator.alloc([]u8, 1);
            args[0] = try allocator.dupe(u8, query[starti..iterator.i]);
            try lenses.append(allocator, .{
                .range = .{ .start = start, .end = pos },
                .command = .{
                    .title = "Run Query",
                    .command = "usrlLanguageServer.runQuery",
                    .arguments = args,
                },
            });
        }

        return .{
            .id = request.id,
            .result = try lenses.toOwnedSlice(allocator),
        };
    }

    pub const Response = struct {
        id: isize,
        result: []const CodeLens([]const u8),
    };
};

pub fn CodeLens(comptime T: type) type {
    return struct {
        range: doc.Range,
        command: ?Command(T) = null,
    };
}

pub fn Command(comptime T: type) type {
    return struct {
        title: []const u8,
        command: []const u8,
        arguments: ?[]const T = null,
    };
}
