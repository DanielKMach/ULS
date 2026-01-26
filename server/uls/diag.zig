const std = @import("std");
const usrl = @import("usrl");
const ULS = @import("../ULS.zig");
const doc = @import("doc.zig");

pub const DocumentDiagnosticRequest = struct {
    pub const method = "textDocument/diagnostic";

    id: isize,
    params: struct {
        textDocument: doc.TextDocumentIdentifier,
    },

    pub fn handle(uls: *ULS, request: @This(), allocator: std.mem.Allocator) ULS.Error!Response {
        const document = uls.docs.get(request.params.textDocument.uri) orelse return error.DocumentNotFound;
        const parser: usrl.Parser = .{ .allocator = allocator };
        const source: usrl.Source = try .anonymous(document.content, allocator);
        defer source.deinit();

        const result = try parser.parse(source);
        if (result == .ok) {
            result.ok.deinit();
            return .{
                .id = request.id,
                .result = .{
                    .kind = "full",
                    .items = &.{},
                },
            };
        }

        var items = std.ArrayList(Diagnostic).empty;
        defer items.deinit(allocator);
        for (result.err) |prob| {
            var writer = std.Io.Writer.Allocating.init(allocator);
            defer writer.deinit();
            const msg = &writer.writer;
            var range: doc.Range = undefined;

            switch (prob) {
                .never_closed_string => |err| {
                    msg.print("Never closed string", .{}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.location, source.source);
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
                    range = try .fromLoc(err.found.loc, source.source);
                },
                .unexpected_character => |err| {
                    msg.print("Unexpected character '{s}'", .{err.location.lexeme(source.source)}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.location, source.source);
                },
                .invalid_number => |err| {
                    msg.print("Invalid number '{s}'", .{err.location.lexeme(source.source)}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.location, source.source);
                },
                .invalid_csharp_identifier => |err| {
                    msg.print("Invalid C# identifier '{s}'", .{err.token.asSlice()}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.token.loc, source.source);
                },
                .invalid_guid => |err| {
                    msg.print("Invalid GUID '{s}'", .{err.token.asSlice()}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.token.loc, source.source);
                },
                .duplicate_clause => |err| {
                    msg.print("Duplicate clause '{s}'", .{err.clause}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.second.loc, source.source);
                },
                .missing_clause => |err| {
                    msg.print("Missing clause '{s}'", .{err.clause}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.placement.loc, source.source);
                },
                .invalid_assignment_target => |err| {
                    msg.print("Invalid assignment target", .{}) catch return error.OutOfMemory;
                    range = try .fromLoc(err.location, source.source);
                },
                .invalid_mode_for_clause => |err| {
                    msg.print("Cannot use search mode '{t}' with clause '{s}'", .{ err.mode, err.clause }) catch return error.OutOfMemory;
                    range = try .fromLoc(err.location, source.source);
                },
                .unexpected => |err| {
                    ULS.log.warn("Unexpected error during parsing: {t}", .{err});
                    continue;
                },
            }

            try items.append(allocator, .{
                .message = try writer.toOwnedSlice(),
                .code = @tagName(prob),
                .range = range,
            });
        }

        return .{
            .id = request.id,
            .result = .{
                .kind = "full",
                .items = try items.toOwnedSlice(allocator),
            },
        };
    }

    pub const Response = struct {
        id: isize,
        result: struct {
            kind: []const u8,
            items: []const Diagnostic,
        },
    };
};

pub const Diagnostic = struct {
    range: doc.Range,
    message: []const u8,
    code: []const u8,
    severity: usize = 1,
    source: []const u8 = "uls",
};
