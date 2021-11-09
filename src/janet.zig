const std = @import("std");
const testing = std.testing;

pub const c = @cImport({
    @cInclude("janet.h");
});

pub fn init() !void {
    if (c.janet_init() != 0) return error.InitError;
}

pub fn deinit() void {
    c.janet_deinit();
}

pub const Janet = struct {
    ptr: *c.Janet,
};

pub const Table = struct {
    ptr: *c.JanetTable,

    const Self = @This();

    pub fn coreEnv(replacements: ?Self) Self {
        if (replacements) |r| {
            return Self{ .ptr = c.janet_core_env(r.ptr) };
        } else {
            return Self{ .ptr = c.janet_core_env(null) };
        }
    }

    pub fn dostring(self: Self, str: []const u8, source_path: []const u8, out: ?Janet) !void {
        const errflags = blk: {
            if (out) |o| {
                break :blk c.janet_dostring(self.ptr, str.ptr, source_path.ptr, o.ptr);
            } else {
                break :blk c.janet_dostring(self.ptr, str.ptr, source_path.ptr, null);
            }
        };
        if (errflags == 0) {
            return;
        } else if ((errflags & 0x01) == 0x01) {
            return error.RuntimeError;
        } else if ((errflags & 0x02) == 0x02) {
            return error.CompileError;
        } else if ((errflags & 0x04) == 0x04) {
            return error.ParseError;
        } else {
            return error.UnexpectedError;
        }
        unreachable;
    }

    pub fn dobytes(
        self: Self,
        bytes: []const u8,
        length: i32,
        source_path: []const u8,
        out: ?Janet,
    ) !void {
        const errflags = blk: {
            if (out) |o| {
                break :blk c.janet_dobytes(self.ptr, bytes.ptr, length, source_path.ptr, o.ptr);
            } else {
                break :blk c.janet_dobytes(self.ptr, bytes.ptr, length, source_path.ptr, null);
            }
        };
        if (errflags == 0) {
            return;
        } else if ((errflags & 0x01) == 0x01) {
            return error.RuntimeError;
        } else if ((errflags & 0x02) == 0x02) {
            return error.CompileError;
        } else if ((errflags & 0x04) == 0x04) {
            return error.ParseError;
        } else {
            return error.UnexpectedError;
        }
        unreachable;
    }
};

test "hello world" {
    try init();
    defer deinit();
    const env: Table = Table.coreEnv(null);
    try env.dostring("(prin `hello, world!`)", "main", null);
}
