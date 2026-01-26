const std = @import("std");
const usrl = @import("usrl");
const ULS = @import("../ULS.zig");

pub const DidOpenTextDocumentNotification = struct {
    pub const method = "textDocument/didOpen";

    params: struct {
        textDocument: TextDocumentItem,
    },

    pub fn handle(uls: *ULS, request: @This(), _: std.mem.Allocator) ULS.Error!void {
        const item = request.params.textDocument;
        const content = try uls.allocator.dupe(u8, item.text);
        errdefer uls.allocator.free(content);

        try uls.docs.put(
            item.uri,
            .{ .version = item.version, .content = content },
        );
        ULS.log.info("Added document {s}", .{item.uri});
    }
};

pub const DidCloseTextDocumentNotification = struct {
    pub const method = "textDocument/didClose";

    params: struct {
        textDocument: TextDocumentIdentifier,
    },

    pub fn handle(uls: *ULS, request: @This(), _: std.mem.Allocator) ULS.Error!void {
        const id = request.params.textDocument;
        if (uls.docs.fetchRemove(id.uri)) |kv| {
            uls.allocator.free(kv.value.content);
            ULS.log.info("Removed document {s}", .{id.uri});
        }
    }
};

pub const DidChangeTextDocumentNotification = struct {
    pub const method = "textDocument/didChange";

    params: struct {
        textDocument: VersionedTextDocumentIdentifier,
        contentChanges: []const TextDocumentContentChangeEvent,
    },

    pub fn handle(uls: *ULS, request: @This(), _: std.mem.Allocator) ULS.Error!void {
        const id = request.params.textDocument;
        const changes = request.params.contentChanges;
        const doc = uls.docs.getPtr(id.uri) orelse return;
        if (doc.version >= id.version) return;

        for (changes) |change| {
            const new = try uls.allocator.dupe(u8, change.text);
            const old = doc.content;

            doc.content = new;
            uls.allocator.free(old);
        }
        ULS.log.info("Updated document {s}", .{id.uri});
    }
};

pub const TextDocumentItem = struct {
    uri: []const u8,
    languageId: []const u8,
    version: isize,
    text: []const u8,
};

pub const TextDocumentIdentifier = struct {
    uri: []const u8,
};

pub const VersionedTextDocumentIdentifier = struct {
    uri: []const u8,
    version: isize, // why tf do they keep using signed integers
};

// tecnically this should be a union with some other stuff
// but since the sync kind is 1 (full) we only need this
pub const TextDocumentContentChangeEvent = struct {
    text: []const u8,
};

pub const Range = struct {
    start: Position, // inclusive
    end: Position, // exclusive

    pub fn fromIndex(from: usize, to: usize, text: []const u8) !@This() {
        std.debug.assert(from < to);
        return .{
            .start = try .fromIndex(from, text),
            .end = try .fromIndex(to, text),
        };
    }

    pub fn fromLoc(loc: usrl.Token.Location, text: []const u8) !@This() {
        return .{
            .start = try .fromIndex(loc.index, text),
            .end = try .fromIndex(loc.index + loc.len, text),
        };
    }
};

pub const Position = struct {
    line: usize, // zero-based
    character: usize, // zero-based

    pub fn fromIndex(index: usize, text: []const u8) !@This() {
        const line_start = if (std.mem.lastIndexOfScalar(u8, text[0..index], '\n')) |line| line + 1 else 0;
        const line_count = std.mem.count(u8, text[0..line_start], "\n");

        return .{
            .line = line_count,
            .character = text[line_start..index].len,
        };
    }
};
