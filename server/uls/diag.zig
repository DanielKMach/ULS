const std = @import("std");
const usrl = @import("usrl");
const lsp = @import("lsp");
const ULS = @import("../ULS.zig");

pub fn @"textDocument/diagnostic"(
    uls: ULS,
    allocator: std.mem.Allocator,
    params: lsp.types.DocumentDiagnosticParams,
) ULS.Error!lsp.types.DocumentDiagnosticReport {
    const document = uls.docs.get(params.textDocument.uri) orelse return error.InvalidParams;
    var problems: std.ArrayList(lsp.types.Diagnostic) = .empty;

    var pdiag: usrl.ParseDiagnostics = .init(allocator);
    defer pdiag.deinit();
    var tdiag: usrl.TokenizeDiagnostics = .init(allocator);
    defer tdiag.deinit();

    if (usrl.tokenize(document, allocator, &tdiag)) |tkns| {
        defer usrl.Token.free(allocator, tkns);

        usrl.check(tkns, allocator, &pdiag) catch |e| switch (e) {
            error.USRLParseError => while (pdiag.pop()) |prob| {
                try problems.append(allocator, .{
                    .code = .{ .string = @tagName(prob) },
                    .message = try std.fmt.allocPrint(allocator, "{f}", .{prob}),
                    .range = ULS.locToRange(document, prob.loc(), uls.encoding),
                });
            },
            else => |err| return err,
        };
    } else |e| switch (e) {
        error.USRLTokenizeError => while (tdiag.pop()) |prob| {
            try problems.append(allocator, .{
                .code = .{ .string = @tagName(prob) },
                .message = try std.fmt.allocPrint(allocator, "{f}", .{prob}),
                .range = ULS.locToRange(document, prob.loc(), uls.encoding),
            });
        },
        else => |err| return err,
    }

    return .{
        .RelatedFullDocumentDiagnosticReport = .{
            .items = try problems.toOwnedSlice(allocator),
        },
    };
}
