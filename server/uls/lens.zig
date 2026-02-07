const std = @import("std");
const lsp = @import("lsp");
const usrl = @import("usrl");
const ULS = @import("../ULS.zig");
// const doc = @import("doc.zig");

pub fn @"textDocument/codeLens"(
    uls: ULS,
    allocator: std.mem.Allocator,
    params: lsp.types.CodeLensParams,
) ULS.Error!?[]const lsp.types.CodeLens {
    const document = uls.docs.get(params.textDocument.uri) orelse return error.InvalidParams;
    var tokenizer = usrl.Tokenizer.init(document);
    var diag = usrl.ParseDiagnostics.init(allocator);
    defer diag.deinit();

    var lenses = std.ArrayList(lsp.types.CodeLens).empty;
    defer lenses.deinit(allocator);

    var parsing = false;
    var start: usize = 0;
    var indent: isize = 0;
    while (tokenizer.token(&diag)) |result| {
        const tkn = result orelse break;
        switch (tkn.value) {
            .SHOW, .RENAME, .EVAL => {
                if (parsing) continue;
                start = tkn.loc.index;
                parsing = true;
            },
            .semicolon, .eof => {
                if (!parsing or indent != 0) continue;
                const pos = tkn.loc.index + tkn.loc.len;
                const args = try allocator.alloc(lsp.types.LSPAny, 1);
                args[0] = .{ .string = try allocator.dupe(u8, document[start..pos]) };
                try lenses.append(allocator, .{
                    .range = .{
                        .start = lsp.offsets.indexToPosition(document, start, uls.encoding),
                        .end = lsp.offsets.indexToPosition(document, pos, uls.encoding),
                    },
                    .command = .{
                        .title = "Run Query",
                        .command = "usrl.runQuery",
                        .arguments = args,
                    },
                });
                parsing = false;
            },
            .left_brace => indent += 1,
            .right_brace => indent -= 1,
            else => {},
        }
    } else |_| {}

    return try lenses.toOwnedSlice(allocator);
}
