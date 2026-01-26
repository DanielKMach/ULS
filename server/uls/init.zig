const std = @import("std");

const ULS = @import("../ULS.zig");

pub const default_capabilities = ServerCapabilities{
    .textDocumentSync = 1, // full
    .codeLensProvider = .{
        .resolveProvider = false,
    },
    .diagnosticProvider = .{
        .identifier = "usrl",
        .interFileDependencies = false,
        .workspaceDiagnostics = false,
    },
};

pub const default_info = ServerInfo{
    .name = "USRL Language Server",
    .version = "0.0.1",
};

pub const InitializeRequest = struct {
    pub const method = "initialize";

    id: isize,
    params: struct {
        clientInfo: ?struct {
            name: []const u8,
            version: []const u8,
        },
    },

    pub fn handle(_: *ULS, request: @This(), _: std.mem.Allocator) ULS.Error!Response {
        if (request.params.clientInfo) |info| {
            ULS.log.info("Connected to {s} v{s}", .{ info.name, info.version });
        } else {
            ULS.log.info("Connected to unknown client...", .{});
        }
        return .{
            .id = request.id,
            .jsonrpc = "2.0",
            .result = .{
                .capabilities = default_capabilities,
                .serverInfo = default_info,
            },
        };
    }

    pub const Response = struct {
        id: ?isize,
        jsonrpc: []const u8,
        result: struct {
            capabilities: ServerCapabilities,
            serverInfo: ServerInfo,
        },
    };
};

pub const ServerCapabilities = struct {
    textDocumentSync: u2,
    codeLensProvider: struct {
        resolveProvider: bool,
    },
    diagnosticProvider: struct {
        identifier: []const u8,
        interFileDependencies: bool,
        workspaceDiagnostics: bool,
    },
};

pub const ServerInfo = struct {
    name: []const u8,
    version: []const u8,
};
