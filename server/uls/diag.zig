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
    const parser: usrl.Parser = .{ .allocator = allocator };
    const source: usrl.Source = try .anonymous(document, allocator);
    defer source.deinit();

    const result = try parser.parse(source);
    if (result == .ok) {
        result.ok.deinit();
        return .{
            .RelatedFullDocumentDiagnosticReport = .{
                .items = &.{},
            },
        };
    }

    var items = std.ArrayList(lsp.types.Diagnostic).empty;
    defer items.deinit(allocator);
    for (result.err) |prob| {
        var writer = std.Io.Writer.Allocating.init(allocator);
        defer writer.deinit();
        const msg = &writer.writer;
        var range: lsp.types.Range = undefined;

        switch (prob) {
            .never_closed_string => |err| {
                msg.print("Never closed string", .{}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.location, uls.encoding);
            },
            .unexpected_token => |err| {
                {
                    msg.print("Unexpected {f}", .{err.found.value}) catch return error.OutOfMemory;
                    if (err.expected.len > 0) msg.print(", expected ", .{}) catch return error.OutOfMemory;
                    for (err.expected, 0..) |expected_type, i| {
                        if (i > 0 and i != err.expected.len - 1) msg.print(", ", .{}) catch return error.OutOfMemory;
                        if (i != 0 and i == err.expected.len - 1) msg.print(" or ", .{}) catch return error.OutOfMemory;
                        msg.print("{f}", .{expected_type}) catch return error.OutOfMemory;
                    }
                }
                range = ULS.locToRange(source.source, err.found.loc, uls.encoding);
            },
            .unexpected_character => |err| {
                msg.print("Unexpected character '{s}'", .{err.location.lexeme(source.source)}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.location, uls.encoding);
            },
            .invalid_number => |err| {
                msg.print("Invalid number '{s}'", .{err.location.lexeme(source.source)}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.location, uls.encoding);
            },
            .invalid_csharp_identifier => |err| {
                msg.print("Invalid C# identifier '{s}'", .{err.token.asSlice()}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.token.loc, uls.encoding);
            },
            .invalid_guid => |err| {
                msg.print("Invalid GUID '{s}'", .{err.token.asSlice()}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.token.loc, uls.encoding);
            },
            .duplicate_clause => |err| {
                msg.print("Duplicate clause '{s}'", .{err.clause}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.second.loc, uls.encoding);
            },
            .missing_clause => |err| {
                msg.print("Missing clause '{s}'", .{err.clause}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.placement.loc, uls.encoding);
            },
            .invalid_assignment_target => |err| {
                msg.print("Invalid assignment target", .{}) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.location, uls.encoding);
            },
            .invalid_mode_for_clause => |err| {
                msg.print("Cannot use search mode '{t}' with clause '{s}'", .{ err.mode, err.clause }) catch return error.OutOfMemory;
                range = ULS.locToRange(source.source, err.location, uls.encoding);
            },
            .unexpected => |err| {
                ULS.log.warn("Unexpected error during parsing: {t}", .{err});
                continue;
            },
        }

        try items.append(allocator, .{
            .message = try writer.toOwnedSlice(),
            .code = .{ .string = @tagName(prob) },
            .range = range,
        });
    }

    return .{
        .RelatedFullDocumentDiagnosticReport = .{
            .items = try items.toOwnedSlice(allocator),
        },
    };
}
