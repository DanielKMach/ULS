const std = @import("std");
const lsp = @import("lsp");
const usrl = @import("usrl");
const ULS = @import("../ULS.zig");

pub fn @"textDocument/didOpen"(
    uls: *ULS,
    _: std.mem.Allocator,
    params: lsp.types.DidOpenTextDocumentParams,
) std.mem.Allocator.Error!void {
    const key = try uls.allocator.dupe(u8, params.textDocument.uri);
    errdefer uls.allocator.free(key);
    const value = try uls.allocator.dupe(u8, params.textDocument.text);
    errdefer uls.allocator.free(value);

    try uls.docs.put(key, value);
    ULS.log.info("Added document {s}", .{std.fs.path.basename(key)});
}

pub fn @"textDocument/didClose"(
    uls: *ULS,
    _: std.mem.Allocator,
    params: lsp.types.DidCloseTextDocumentParams,
) void {
    const doc = params.textDocument;
    if (uls.docs.fetchRemove(doc.uri)) |kv| {
        uls.allocator.free(kv.key);
        uls.allocator.free(kv.value);
        ULS.log.info("Removed document {s}", .{std.fs.path.basename(doc.uri)});
    }
}

pub fn @"textDocument/didChange"(
    uls: *ULS,
    _: std.mem.Allocator,
    params: lsp.types.DidChangeTextDocumentParams,
) std.mem.Allocator.Error!void {
    const doc = params.textDocument;
    for (params.contentChanges) |change| {
        std.debug.assert(change == .literal_1);

        const new = try uls.allocator.dupe(u8, change.literal_1.text);
        const old = try uls.docs.fetchPut(doc.uri, new) orelse continue;
        uls.allocator.free(old.value);
    }
}
