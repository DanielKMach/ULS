const std = @import("std");
const usrl = @import("usrl");
const lsp = @import("lsp");

pub const log = std.log.scoped(.uls);
pub const init = @import("uls/init.zig");
pub const doc = @import("uls/doc.zig");
pub const lens = @import("uls/lens.zig");
pub const diag = @import("uls/diag.zig");
pub const hl = @import("uls/hl.zig");
pub const hover = @import("uls/hover.zig");

pub const Document = struct {
    version: isize,
    content: []const u8,
};

pub const Error = lsp.basic_server.Error || std.mem.Allocator.Error;

allocator: std.mem.Allocator,
docs: std.StringHashMap([]u8),
encoding: lsp.offsets.Encoding = .@"utf-8",

pub const initialize = init.initialize;
pub const initialized = init.initialized;
pub const @"textDocument/didOpen" = doc.@"textDocument/didOpen";
pub const @"textDocument/didClose" = doc.@"textDocument/didClose";
pub const @"textDocument/didChange" = doc.@"textDocument/didChange";
pub const @"textDocument/codeLens" = lens.@"textDocument/codeLens";
pub const @"textDocument/diagnostic" = diag.@"textDocument/diagnostic";
pub const @"textDocument/semanticTokens/full" = hl.@"textDocument/semanticTokens/full";
pub const @"textDocument/hover" = hover.@"textDocument/hover";

pub fn onResponse(
    _: *@This(),
    _: std.mem.Allocator,
    response: lsp.JsonRPCMessage.Response,
) void {
    std.log.warn("received unexpected response from client with id '{?}'!", .{response.id});
}

pub fn locToRange(text: []const u8, loc: usrl.Token.Location, encoding: lsp.offsets.Encoding) lsp.types.Range {
    return .{
        .start = lsp.offsets.indexToPosition(text, loc.index, encoding),
        .end = lsp.offsets.indexToPosition(text, loc.index + loc.len, encoding),
    };
}
