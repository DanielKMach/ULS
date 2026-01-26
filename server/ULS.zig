const std = @import("std");
const rpc = @import("rpc.zig");

pub const log = std.log.scoped(.uls);
pub const init = @import("uls/init.zig");
pub const doc = @import("uls/doc.zig");
pub const lens = @import("uls/lens.zig");
pub const diag = @import("uls/diag.zig");

pub const request_handlers: []const type = &[_]type{
    init.InitializeRequest,
    doc.DidOpenTextDocumentNotification,
    doc.DidCloseTextDocumentNotification,
    doc.DidChangeTextDocumentNotification,
    lens.CodeLensRequest,
    diag.DocumentDiagnosticRequest,
};

pub const Document = struct {
    version: isize,
    content: []const u8,
};

pub const CheckResult = struct {
    msg: []const u8,
    start: doc.Position,
    len: usize,
};

pub const Message = struct {
    method: []const u8,
    id: ?isize = null,

    pub fn isRequest(self: @This()) bool {
        return self.id != null;
    }
};

pub const ErrorResponse = struct {
    id: isize,
    @"error": struct {
        code: isize,
        message: []const u8,
    },
};

pub const Error = error{ DocumentNotFound, InvalidUtf8 } || std.mem.Allocator.Error;

allocator: std.mem.Allocator,
docs: std.StringHashMap(Document),

pub fn handleMsg(uls: *@This(), content: []const u8, out: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    const msg: Message = try std.json.parseFromSliceLeaky(Message, allocator, content, rpc.parse_opts);
    log.info("Received '{s}'", .{msg.method});

    var found = false;
    inline for (request_handlers) |Handler| {
        if (!@hasDecl(Handler, "method")) @compileError(@typeName(Handler) ++ " does not contain method");
        if (!@hasDecl(Handler, "handle")) @compileError(@typeName(Handler) ++ " does not contain handle function");

        if (std.mem.eql(u8, msg.method, Handler.method)) {
            found = true;
            log.info("Found apropriate handler", .{});

            const req = try std.json.parseFromSliceLeaky(Handler, allocator, content, rpc.parse_opts);
            const resp = Handler.handle(uls, req, allocator);
            if (resp) |rsp| {
                if (msg.isRequest()) {
                    if (@TypeOf(rsp) == void) @panic("request handlers must always have a response");
                    log.info("Sending response...", .{});
                    try rpc.sendMsg(rsp, out);
                } else {
                    if (@TypeOf(rsp) != void) log.warn("Discarded response since message is notification.", .{});
                }
            } else |e| {
                log.warn("Error on handling message: {t}", .{e});
                if (msg.isRequest()) {
                    log.info("Sending error response...", .{});
                    const response = ErrorResponse{
                        .id = msg.id.?,
                        .@"error" = .{
                            .code = errToCode(e),
                            .message = @errorName(e),
                        },
                    };
                    try rpc.sendMsg(response, out);
                }
            }
        }
    }
    if (!found and msg.isRequest()) {
        log.warn("Handler not found. Sending response...", .{});
        const response = ErrorResponse{
            .id = msg.id.?,
            .@"error" = .{
                .code = -32601,
                .message = "MethodNotImplemented",
            },
        };
        try rpc.sendMsg(response, out);
    }
}

pub fn errToCode(err: Error) isize {
    return switch (err) {
        error.DocumentNotFound => -32602,
        error.InvalidUtf8 => -32803,
        error.OutOfMemory => -32603,
    };
}
