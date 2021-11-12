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

pub fn fromCJanet(j: c.Janet) Janet {
    return @ptrCast(*const Janet, &j).*;
}
pub fn wrapKeyword(str: [:0]const u8) Janet {
    return fromCJanet(c.janet_wrap_keyword(str.ptr));
}
pub fn ckeywordv(str: [:0]const u8) Janet {
    return fromCJanet(c.janet_ckeywordv(str.ptr));
}
pub fn keywordv(str: []const u8) Janet {
    return fromCJanet(c.janet_keywordv(str.ptr, @intCast(i32, str.len)));
}
pub fn keyword(str: []const u8) Keyword {
    return c.janet_keyword(str.ptr, @intCast(i32, str.len));
}
pub fn ckeyword(str: [:0]const u8) Keyword {
    return c.janet_ckeyword(str.ptr);
}
pub fn wrapSymbol(str: [:0]const u8) Janet {
    return fromCJanet(c.janet_wrap_symbol(str.ptr));
}
pub fn csymbolv(str: [:0]const u8) Janet {
    return fromCJanet(c.janet_csymbolv(str.ptr));
}
pub fn symbolv(str: []const u8) Janet {
    return fromCJanet(c.janet_symbolv(str.ptr, @intCast(i32, str.len)));
}
pub fn symbol(str: []const u8) Symbol {
    return c.janet_symbol(str.ptr, @intCast(i32, str.len));
}
pub fn csymbol(str: [:0]const u8) Symbol {
    return c.janet_csymbol(str.ptr);
}
pub fn wrapString(str: [:0]const u8) Janet {
    return fromCJanet(c.janet_wrap_string(str.ptr));
}
pub fn cstringv(str: [:0]const u8) Janet {
    return fromCJanet(c.janet_cstringv(str.ptr));
}
pub fn stringv(str: []const u8) Janet {
    return fromCJanet(c.janet_stringv(str.ptr, @intCast(i32, str.len)));
}
pub fn string(str: []const u8) String {
    return c.janet_string(str.ptr, @intCast(i32, str.len));
}
pub fn cstring(str: [:0]const u8) String {
    return c.janet_cstring(str.ptr);
}

pub fn wrapInteger(n: i32) Janet {
    return fromCJanet(c.janet_wrap_integer(n));
}

pub fn symbolGen() Symbol {
    return c.janet_symbol_gen();
}

pub const Janet = blk: {
    if (std.builtin.target.cpu.arch == .x86_64) {
        break :blk extern union {
            @"u64": u64,
            @"i64": i64,
            number: f64,
            pointer: *c_void,

            pub usingnamespace JanetMixin(@This());
        };
    } else if (std.builtin.target.cpu.arch.endianess() == .Big) {
        break :blk extern union {
            tagged: extern struct {
                @"type": u32,
                payload: extern union {
                    integer: u32,
                    pointer: *c_void,
                },
            },
            number: f64,
            @"u64": u64,

            pub usingnamespace JanetMixin(@This());
        };
    } else if (std.builtin.target.cpu.arch.endianess() == .Little) {
        break :blk extern union {
            tagged: extern struct {
                payload: extern union {
                    integer: u32,
                    pointer: *c_void,
                },
                @"type": u32,
            },
            number: f64,
            @"u64": u64,

            pub usingnamespace JanetMixin(@This());
        };
    } else {
        // TODO: This is when JANET_NO_NANBOX is defined, we probably need some condition
        // to enable it.
        break :blk extern struct {
            as: extern union {
                @"u64": u64,
                number: f64,
                integer: i32,
                pointer: *c_void,
                cpointer: *const c_void,
            },
            @"type": c.JanetType,

            pub usingnamespace JanetMixin(@This());
        };
    }
};

const JanetType = extern enum {
    number,
    nil,
    boolean,
    fiber,
    string,
    symbol,
    keyword,
    array,
    tuple,
    table,
    @"struct",
    buffer,
    function,
    cfunction,
    abstract,
    pointer,
};

pub const TFLAG_NIL = (1 << @enumToInt(JanetType.nil));
pub const TFLAG_BOOLEAN = (1 << @enumToInt(JanetType.boolean));
pub const TFLAG_FIBER = (1 << @enumToInt(JanetType.fiber));
pub const TFLAG_NUMBER = (1 << @enumToInt(JanetType.number));
pub const TFLAG_STRING = (1 << @enumToInt(JanetType.string));
pub const TFLAG_SYMBOL = (1 << @enumToInt(JanetType.symbol));
pub const TFLAG_KEYWORD = (1 << @enumToInt(JanetType.keyword));
pub const TFLAG_ARRAY = (1 << @enumToInt(JanetType.array));
pub const TFLAG_TUPLE = (1 << @enumToInt(JanetType.tuple));
pub const TFLAG_TABLE = (1 << @enumToInt(JanetType.table));
pub const TFLAG_STRUCT = (1 << @enumToInt(JanetType.@"struct"));
pub const TFLAG_BUFFER = (1 << @enumToInt(JanetType.buffer));
pub const TFLAG_FUNCTION = (1 << @enumToInt(JanetType.function));
pub const TFLAG_CFUNCTION = (1 << @enumToInt(JanetType.cfunction));
pub const TFLAG_ABSTRACT = (1 << @enumToInt(JanetType.abstract));
pub const TFLAG_POINTER = (1 << @enumToInt(JanetType.pointer));

// Some abstractions
pub const TFLAG_BYTES = TFLAG_STRING | TFLAG_SYMBOL | TFLAG_BUFFER | TFLAG_KEYWORD;
pub const TFLAG_INDEXED = TFLAG_ARRAY | TFLAG_TUPLE;
pub const TFLAG_DICTIONARY = TFLAG_TABLE | TFLAG_STRUCT;
pub const TFLAG_LENGTHABLE = TFLAG_BYTES | TFLAG_INDEXED | TFLAG_DICTIONARY;
pub const TFLAG_CALLABLE = TFLAG_FUNCTION | TFLAG_CFUNCTION | TFLAG_LENGTHABLE | TFLAG_ABSTRACT;

// Missing type unwraps:
// JanetFiber *janet_unwrap_fiber(Janet x);
// JanetArray *janet_unwrap_array(Janet x);
// JanetTable *janet_unwrap_table(Janet x);
// JanetBuffer *janet_unwrap_buffer(Janet x);
// void *janet_unwrap_abstract(Janet x);
// void *janet_unwrap_pointer(Janet x);
// JanetFunction *janet_unwrap_function(Janet x);
// JanetCFunction janet_unwrap_cfunction(Janet x);

pub fn JanetMixin(comptime Self: type) type {
    return struct {
        pub fn unwrapInteger(self: Self) !i32 {
            if (!self.checktype(.number)) return error.NotNumber;
            return c.janet_unwrap_integer(self.toCJanet());
        }

        pub fn unwrapNumber(self: Self) !f64 {
            if (!self.checktype(.number)) return error.NotNumber;
            return c.janet_unwrap_number(self.toCJanet());
        }

        pub fn unwrapBoolean(self: Self) !bool {
            if (!self.checktype(.boolean)) return error.NotBoolean;
            return c.janet_unwrap_boolean(self.toCJanet()) > 0;
        }

        pub fn unwrapString(self: Self) ![]const u8 {
            if (!self.checktype(.string)) return error.NotString;
            const rs = c.janet_unwrap_string(self.toCJanet());
            return std.mem.span(@ptrCast([*:0]const u8, rs));
        }

        pub fn unwrapKeyword(self: Self) ![]const u8 {
            if (!self.checktype(.keyword)) return error.NotKeyword;
            const rs = c.janet_unwrap_keyword(self.toCJanet());
            return std.mem.span(@ptrCast([*:0]const u8, rs));
        }

        pub fn unwrapSymbol(self: Self) ![]const u8 {
            if (!self.checktype(.symbol)) return error.NotSymbol;
            const rs = c.janet_unwrap_symbol(self.toCJanet());
            return std.mem.span(@ptrCast([*:0]const u8, rs));
        }

        pub fn unwrapTuple(self: Self) !Tuple {
            if (!self.checktype(.tuple)) return error.NotTuple;
            const ptr = @ptrCast([*]const Self, c.janet_unwrap_tuple(self.toCJanet()));
            const head = c.janet_tuple_head(@ptrCast(*const c.Janet, ptr));
            const aligned_head = @alignCast(@alignOf(*TupleHead), head);
            const cast_head = @ptrCast(*TupleHead, aligned_head);
            const l = @intCast(usize, cast_head.length);
            return Tuple.init(ptr[0..l]);
        }

        pub fn unwrapStruct(self: Self) !Struct {
            if (!self.checktype(.@"struct")) return error.NotStruct;
            const ptr = @ptrCast([*]const KV, c.janet_unwrap_struct(self.toCJanet()));
            return Struct.init(ptr);
        }

        pub fn checktype(self: Self, typ: JanetType) bool {
            return c.janet_checktype(self.toCJanet(), @ptrCast(*const c.JanetType, &typ).*) > 0;
        }

        pub fn checktypes(self: Self, typeflags: i32) bool {
            return c.janet_checktypes(self.toCJanet(), typeflags) > 0;
        }

        pub fn janetType(self: Self) JanetType {
            return @ptrCast(*JanetType, &c.janet_type(self.toCJanet())).*;
        }

        pub fn toCJanet(self: *const Self) c.Janet {
            return @ptrCast(*const c.Janet, self).*;
        }
    };
}

pub const Tuple = struct {
    val: Type,

    pub const Type = []const Janet;
    const Self = @This();

    pub fn init(data: Type) Self {
        return Self{ .val = data };
    }

    pub fn head(self: Self) !*TupleHead {
        const head = c.janet_tuple_head(@ptrCast(*const c.Janet, self.val.ptr));
        const aligned_head = @alignCast(@alignOf(*TupleHead), head);
        return @ptrCast(*TupleHead, aligned_head);
    }
};

pub const Struct = struct {
    ptr: Type,

    pub const Type = [*]const KV;
    const Self = @This();

    pub fn init(data: Type) Self {
        return Self{ .ptr = data };
    }

    pub fn head(self: Self) !*StructHead {
        const head = c.janet_struct_head(@ptrCast(*const c.JanetKV, self.ptr));
        const aligned_head = @alignCast(@alignOf(*StructHead), head);
        return @ptrCast(*StructHead, aligned_head);
    }

    pub fn find(self: Self, key: Janet) ?*const KV {
        return @ptrCast(?*const KV, c.janet_struct_find(self.toCJanet(), key.toCJanet()));
    }

    pub fn get(self: Self, key: Janet) Janet {
        return fromCJanet(c.janet_struct_get(self.toCJanet(), key.toCJanet()));
    }

    pub fn toCJanet(self: Self) [*c]const c.JanetKV {
        return @ptrCast([*]const c.JanetKV, self.ptr);
    }
};

pub const KV = extern struct {
    key: Janet,
    value: Janet,
};

pub const String = [*:0]const u8;
pub const Symbol = [*:0]const u8;
pub const Keyword = [*:0]const u8;
pub const Abstract = *c_void;

pub const GCObject = extern struct {
    flags: i32,
    blocks: extern union {
        next: *GCObject,
        refcount: i32,
    },
};

pub const TupleHead = extern struct {
    gc: GCObject,
    length: i32,
    hash: i32,
    sm_line: i32,
    sm_column: i32,
    data: [*]const Janet,
};

pub const StructHead = extern struct {
    gc: GCObject,
    length: i32,
    hash: i32,
    capacity: i32,
    data: [*]const KV,
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

    pub fn dostring(self: Self, str: [:0]const u8, source_path: [:0]const u8, out: ?*Janet) !void {
        return try dobytes(self, str, @intCast(i32, str.len), source_path, out);
    }

    pub fn dobytes(
        self: Self,
        bytes: [:0]const u8,
        length: i32,
        source_path: [:0]const u8,
        out: ?*Janet,
    ) !void {
        const errflags = blk: {
            if (out) |o| {
                break :blk c.janet_dobytes(
                    self.ptr,
                    bytes.ptr,
                    length,
                    source_path.ptr,
                    @ptrCast([*c]c.Janet, o),
                );
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

test "unwrap values" {
    try init();
    defer deinit();
    const env: Table = Table.coreEnv(null);
    {
        var value: Janet = undefined;
        try env.dostring("1", "main", &value);
        try testing.expectEqual(@as(i32, 1), try value.unwrapInteger());
    }
    {
        var value: Janet = undefined;
        try env.dostring("1", "main", &value);
        try testing.expectEqual(@as(f64, 1), try value.unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try env.dostring("true", "main", &value);
        try testing.expectEqual(true, try value.unwrapBoolean());
    }
    {
        var value: Janet = undefined;
        try env.dostring("\"str\"", "main", &value);
        try testing.expectEqualStrings("str", try value.unwrapString());
    }
    {
        var value: Janet = undefined;
        try env.dostring(":str", "main", &value);
        try testing.expectEqualStrings("str", try value.unwrapKeyword());
    }
    {
        var value: Janet = undefined;
        try env.dostring("'str", "main", &value);
        try testing.expectEqualStrings("str", try value.unwrapSymbol());
    }
    {
        var value: Janet = undefined;
        try env.dostring("[58 true 36.0]", "main", &value);
        const tuple = try value.unwrapTuple();
        try testing.expectEqual(@as(usize, 3), tuple.val.len);
        try testing.expectEqual(@as(i32, 58), try tuple.val[0].unwrapInteger());
        try testing.expectEqual(true, try tuple.val[1].unwrapBoolean());
        try testing.expectEqual(@as(f64, 36), try tuple.val[2].unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try env.dostring("{:kw 2 'sym 8 98 56}", "main", &value);
        _ = try value.unwrapStruct();
    }
}

test "janet_type" {
    try init();
    defer deinit();
    const env: Table = Table.coreEnv(null);
    var value: Janet = undefined;
    try env.dostring("1", "main", &value);
    try testing.expectEqual(JanetType.number, value.janetType());
}

test "janet_checktypes" {
    try init();
    defer deinit();
    const env: Table = Table.coreEnv(null);
    {
        var value: Janet = undefined;
        try env.dostring("1", "main", &value);
        try testing.expectEqual(true, value.checktypes(TFLAG_NUMBER));
    }
    {
        var value: Janet = undefined;
        try env.dostring(":str", "main", &value);
        try testing.expectEqual(true, value.checktypes(TFLAG_BYTES));
    }
}

test "struct" {
    try init();
    defer deinit();
    const env: Table = Table.coreEnv(null);
    var value: Janet = undefined;
    try env.dostring("{:kw 2 'sym 8 98 56}", "main", &value);
    const struc = try value.unwrapStruct();
    const first_kv = struc.get(keywordv("kw"));
    const second_kv = struc.get(symbolv("sym"));
    const third_kv = struc.get(wrapInteger(98));
    const none_kv = struc.get(wrapInteger(123));
    try testing.expectEqual(@as(i32, 2), try first_kv.unwrapInteger());
    try testing.expectEqual(@as(i32, 8), try second_kv.unwrapInteger());
    try testing.expectEqual(@as(i32, 56), try third_kv.unwrapInteger());
    try testing.expectEqual(JanetType.nil, none_kv.janetType());
}
