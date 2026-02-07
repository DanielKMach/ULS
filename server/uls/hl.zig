const std = @import("std");
const usrl = @import("usrl");
const lsp = @import("lsp");
const ULS = @import("../ULS.zig");
const hover = @import("hover.zig");

pub fn @"textDocument/semanticTokens/full"(
    uls: ULS,
    allocator: std.mem.Allocator,
    params: lsp.types.SemanticTokensParams,
) ULS.Error!?lsp.types.SemanticTokens {
    const document = uls.docs.get(params.textDocument.uri) orelse return error.InvalidParams;
    var tokenizer = usrl.Tokenizer.init(document);
    var diag = usrl.ParseDiagnostics.init(allocator);
    defer diag.deinit();

    var encoded = std.ArrayList(u32).empty;
    defer encoded.deinit(allocator);

    var last = std.mem.zeroes(lsp.types.Position);
    while (tokenizer.token(&diag)) |result| {
        const tkn = result orelse break;
        const tid = tokenToType(tkn) orelse continue;
        const range = ULS.locToRange(document, tkn.loc, uls.encoding);
        const len = lsp.offsets.rangeLength(document, range, uls.encoding);
        try encoded.appendSlice(allocator, &.{
            range.start.line - last.line,
            if (range.start.line == last.line) range.start.character - last.character else range.start.character,
            @intCast(len),
            tid,
            0,
        });
        last = range.start;
    } else |_| {}

    return .{ .data = try encoded.toOwnedSlice(allocator) };
}

fn tokenToType(tkn: usrl.Token) ?u32 {
    if (tkn.value == .variable) {
        if (hover.descriptions.has(tkn.value.variable)) return 6;
    }

    return switch (tkn.value) {
        .dot, .comma, .colon, .semicolon, .left_paren, .right_paren, .left_bracket, .right_bracket, .left_brace, .right_brace, .eof => null,
        .SHOW, .RENAME, .EVAL, .UPDATE, .OF, .IN, .WHERE, .AND, .OR, .NOT, .GUID, .DIRECT, .INDIRECT, .REFS, .USES, .FOR, .NIL => 0,
        .plus, .minus, .star, .slash, .percentage, .equal, .plus_equal, .minus_equal, .star_equal, .slash_equal, .colon_equal, .greater, .greater_equal, .less, .less_equal, .bang_equal, .equal_equal, .question_question, .question => 1,
        .number => 2,
        .string => 3,
        .literal => 4,
        .variable => 5,
    };
}
