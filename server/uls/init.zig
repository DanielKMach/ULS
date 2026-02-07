const std = @import("std");
const lsp = @import("lsp");

const ULS = @import("../ULS.zig");

pub fn initialize(
    uls: *ULS,
    _: std.mem.Allocator,
    params: lsp.types.InitializeParams,
) lsp.types.InitializeResult {
    if (params.clientInfo) |info| {
        ULS.log.info("Connected to {s}", .{info.name});
    } else {
        ULS.log.info("Connected to unknown client...", .{});
    }
    uls.encoding = blk: { // utf-8 if an option, otherwise utf-16
        const general = params.capabilities.general orelse break :blk .@"utf-16";
        const encodings = general.positionEncodings orelse break :blk .@"utf-16";
        break :blk for (encodings) |e| {
            if (e == .@"utf-8") break .@"utf-8";
        } else .@"utf-16";
    };
    ULS.log.info("Selected '{t}' encoding", .{uls.encoding});

    return .{
        .capabilities = getCapabilities(if (params.clientInfo) |i| i.name else "", uls.encoding),
        .serverInfo = .{
            .name = "USRL Language Server",
            .version = "0.0.1",
        },
    };
}

pub fn initialized(
    _: ULS,
    _: std.mem.Allocator,
    _: lsp.types.InitializedParams,
) void {
    ULS.log.info("ULS initialized", .{});
}

fn getCapabilities(editor: []const u8, encoding: lsp.offsets.Encoding) lsp.types.ServerCapabilities {
    var capabilities = lsp.types.ServerCapabilities{
        .textDocumentSync = .{ .TextDocumentSyncKind = .Full },
        .codeLensProvider = .{
            .resolveProvider = false,
        },
        .diagnosticProvider = .{
            .DiagnosticOptions = .{
                .identifier = "usrl",
                .interFileDependencies = false,
                .workspaceDiagnostics = false,
            },
        },
        .hoverProvider = .{ .bool = true },
        .positionEncoding = switch (encoding) {
            .@"utf-8" => .@"utf-8",
            .@"utf-16" => .@"utf-16",
            .@"utf-32" => .@"utf-32",
        },
    };
    if (!std.mem.eql(u8, editor, "Visual Studio Code")) { // vscode uses better external grammar
        capabilities.semanticTokensProvider = .{
            .SemanticTokensOptions = .{
                .legend = .{
                    .tokenModifiers = &.{},
                    .tokenTypes = &.{ "keyword", "operator", "number", "string", "property", "variable", "function" },
                },
                .full = .{ .bool = true },
            },
        };
    }
    return capabilities;
}
