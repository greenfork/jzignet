const std = @import("std");
const testing = std.testing;

pub const c = @cImport({
    @cInclude("janet.h");
});

// Helper functions

pub fn fromPtr(comptime ty: type, ptr: *c_void) ty {
    return @ptrCast(ty, @alignCast(@alignOf(ty), ptr));
}

// Bindings

pub fn init() !void {
    if (c.janet_init() != 0) return error.InitError;
}
pub fn deinit() void {
    c.janet_deinit();
}

pub fn coreEnv(replacements: ?*Table) *Table {
    if (replacements) |r| {
        return Table.fromC(c.janet_core_env(r.toC()));
    } else {
        return Table.fromC(c.janet_core_env(null));
    }
}

pub fn dostring(env: *Table, str: [:0]const u8, source_path: [:0]const u8, out: ?*Janet) !void {
    return try dobytes(env, str, @intCast(i32, str.len), source_path, out);
}

pub fn dobytes(
    env: *Table,
    bytes: [:0]const u8,
    length: i32,
    source_path: [:0]const u8,
    out: ?*Janet,
) !void {
    const errflags = blk: {
        if (out) |o| {
            break :blk c.janet_dobytes(
                env.toC(),
                bytes.ptr,
                length,
                source_path.ptr,
                @ptrCast([*c]c.Janet, o),
            );
        } else {
            break :blk c.janet_dobytes(env.toC(), bytes.ptr, length, source_path.ptr, null);
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

pub fn wrapKeyword(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_wrap_keyword(str.ptr));
}
pub fn ckeywordv(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_ckeywordv(str.ptr));
}
pub fn keywordv(str: []const u8) Janet {
    return Janet.fromC(c.janet_keywordv(str.ptr, @intCast(i32, str.len)));
}
pub fn keyword(str: []const u8) Keyword {
    return c.janet_keyword(str.ptr, @intCast(i32, str.len));
}
pub fn ckeyword(str: [:0]const u8) Keyword {
    return c.janet_ckeyword(str.ptr);
}
pub fn wrapSymbol(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_wrap_symbol(str.ptr));
}
pub fn csymbolv(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_csymbolv(str.ptr));
}
pub fn symbolv(str: []const u8) Janet {
    return Janet.fromC(c.janet_symbolv(str.ptr, @intCast(i32, str.len)));
}
pub fn symbol(str: []const u8) Symbol {
    return c.janet_symbol(str.ptr, @intCast(i32, str.len));
}
pub fn csymbol(str: [:0]const u8) Symbol {
    return c.janet_csymbol(str.ptr);
}
pub fn wrapString(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_wrap_string(str.ptr));
}
pub fn cstringv(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_cstringv(str.ptr));
}
pub fn stringv(str: []const u8) Janet {
    return Janet.fromC(c.janet_stringv(str.ptr, @intCast(i32, str.len)));
}
pub fn string(str: []const u8) String {
    return c.janet_string(str.ptr, @intCast(i32, str.len));
}
pub fn cstring(str: [:0]const u8) String {
    return c.janet_cstring(str.ptr);
}

pub fn abstract(at: *const AbstractType, size: usize) *c_void {
    return c.janet_abstract(at.toC(), size) orelse unreachable;
}

pub fn symbolGen() Symbol {
    return c.janet_symbol_gen();
}

pub fn panic(message: [:0]const u8) noreturn {
    c.janet_panic(message.ptr);
}
pub fn printf(message: [:0]const u8) void {
    c.janet_dynprintf("out", std.io.getStdOut().handle, message.ptr);
}
pub fn eprintf(message: [:0]const u8) void {
    c.janet_dynprintf("err", std.io.getStdErr().handle, message.ptr);
}

pub fn arity(ary: i32, min: i32, max: i32) void {
    c.janet_arity(ary, min, max);
}
pub fn fixarity(ary: i32, fix: i32) void {
    c.janet_fixarity(ary, fix);
}

pub fn getNat(argv: [*]const Janet, n: i32) i32 {
    return c.janet_getnat(Janet.toCPtr(argv), n);
}
pub fn getAbstract(argv: [*]const Janet, n: i32, at: *const AbstractType) *c_void {
    // Function implementation does not ever return NULL.
    return c.janet_getabstract(Janet.toCPtr(argv), n, at.toC()) orelse unreachable;
}
pub fn optNat(argv: [*]const Janet, argc: i32, n: i32, dflt: i32) i32 {
    return c.janet_optnat(Janet.toCPtr(argv), argc, n, dflt);
}
pub fn wrapNil() Janet {
    return Janet.fromC(c.janet_wrap_nil());
}
pub fn wrapInteger(n: i32) Janet {
    return Janet.fromC(c.janet_wrap_integer(n));
}
pub fn wrapAbstract(p: *c_void) Janet {
    return Janet.fromC(c.janet_wrap_abstract(p));
}

pub fn cfuns(env: *Table, regprefix: [:0]const u8, funs: [*]const Reg) void {
    return c.janet_cfuns(env.toC(), regprefix.ptr, @ptrCast([*c]const c.JanetReg, funs));
}
pub fn cfunsExt(env: *Table, regprefix: [:0]const u8, funs: [*]const RegExt) void {
    return c.janet_cfuns_ext(env.toC(), regprefix.ptr, @ptrCast([*c]const c.JanetRegExt, funs));
}
pub fn cfunsPrefix(env: *Table, regprefix: [:0]const u8, funs: [*]const Reg) void {
    return c.janet_cfuns_prefix(env.toC(), regprefix.ptr, @ptrCast([*c]const c.JanetReg, funs));
}
pub fn cfunsExtPrefix(env: *Table, regprefix: [:0]const u8, funs: [*]const RegExt) void {
    return c.janet_cfuns_ext_prefix(env.toC(), regprefix.ptr, @ptrCast([*c]const c.JanetRegExt, funs));
}

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

pub const Janet = blk: {
    if (std.builtin.target.cpu.arch == .x86_64) {
        break :blk extern union {
            @"u64": u64,
            @"i64": i64,
            number: f64,
            pointer: *c_void,

            pub usingnamespace JanetMixin;
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

            pub usingnamespace JanetMixin;
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

            pub usingnamespace JanetMixin;
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

            pub usingnamespace JanetMixin;
        };
    }
};

// Missing type unwraps:
// JanetFiber *janet_unwrap_fiber(Janet x);
// JanetFunction *janet_unwrap_function(Janet x);
// JanetCFunction janet_unwrap_cfunction(Janet x);

const JanetMixin = struct {
    pub fn fromC(janet: c.Janet) Janet {
        return @ptrCast(*const Janet, &janet).*;
    }
    pub fn toC(janet: *const Janet) c.Janet {
        return @ptrCast(*const c.Janet, janet).*;
    }
    pub fn toCPtr(janet: [*]const Janet) [*c]const c.Janet {
        return @ptrCast([*c]const c.Janet, janet);
    }

    pub fn unwrapInteger(janet: Janet) !i32 {
        if (!janet.checktype(.number)) return error.NotNumber;
        return c.janet_unwrap_integer(janet.toC());
    }

    pub fn unwrapNumber(janet: Janet) !f64 {
        if (!janet.checktype(.number)) return error.NotNumber;
        return c.janet_unwrap_number(janet.toC());
    }

    pub fn unwrapBoolean(janet: Janet) !bool {
        if (!janet.checktype(.boolean)) return error.NotBoolean;
        return c.janet_unwrap_boolean(janet.toC()) > 0;
    }

    pub fn unwrapString(janet: Janet) ![]const u8 {
        if (!janet.checktype(.string)) return error.NotString;
        const rs = c.janet_unwrap_string(janet.toC());
        return std.mem.span(@ptrCast([*:0]const u8, rs));
    }

    pub fn unwrapKeyword(janet: Janet) ![]const u8 {
        if (!janet.checktype(.keyword)) return error.NotKeyword;
        const rs = c.janet_unwrap_keyword(janet.toC());
        return std.mem.span(@ptrCast([*:0]const u8, rs));
    }

    pub fn unwrapSymbol(janet: Janet) ![]const u8 {
        if (!janet.checktype(.symbol)) return error.NotSymbol;
        const rs = c.janet_unwrap_symbol(janet.toC());
        return std.mem.span(@ptrCast([*:0]const u8, rs));
    }

    pub fn unwrapTuple(janet: Janet) !Tuple {
        if (!janet.checktype(.tuple)) return error.NotTuple;
        const ptr = @ptrCast([*]const Janet, c.janet_unwrap_tuple(janet.toC()));
        const head = c.janet_tuple_head(@ptrCast(*const c.Janet, ptr));
        const aligned_head = @alignCast(@alignOf(*Tuple.Head), head);
        const cast_head = @ptrCast(*Tuple.Head, aligned_head);
        const l = @intCast(usize, cast_head.length);
        return Tuple.init(ptr[0..l]);
    }

    pub fn unwrapArray(janet: Janet) !*Array {
        if (!janet.checktype(.array)) return error.NotArray;
        return @ptrCast(*Array, c.janet_unwrap_array(janet.toC()));
    }

    pub fn unwrapBuffer(janet: Janet) !*Buffer {
        if (!janet.checktype(.buffer)) return error.NotBuffer;
        return @ptrCast(*Buffer, c.janet_unwrap_buffer(janet.toC()));
    }

    pub fn unwrapStruct(janet: Janet) !Struct {
        if (!janet.checktype(.@"struct")) return error.NotStruct;
        const ptr = @ptrCast([*]const KV, c.janet_unwrap_struct(janet.toC()));
        return Struct.init(ptr);
    }

    pub fn unwrapTable(janet: Janet) !*Table {
        if (!janet.checktype(.table)) return error.NotTable;
        return @ptrCast(*Table, c.janet_unwrap_table(janet.toC()));
    }

    pub fn unwrapPointer(janet: Janet) *c_void {
        if (!janet.checktype(.pointer)) return error.NotPointer;
        return c.janet_unwrap_pointer(janet.toC());
    }

    pub fn unwrapAbstract(janet: Janet) *c_void {
        if (!janet.checktype(.abstract)) return error.NotAbstract;
        return c.janet_unwrap_abstract(janet.toC());
    }

    pub fn checktype(janet: Janet, typ: JanetType) bool {
        return c.janet_checktype(janet.toC(), @ptrCast(*const c.JanetType, &typ).*) > 0;
    }

    pub fn checktypes(janet: Janet, typeflags: i32) bool {
        return c.janet_checktypes(janet.toC(), typeflags) > 0;
    }

    pub fn janetType(janet: Janet) JanetType {
        return @ptrCast(*JanetType, &c.janet_type(janet.toC())).*;
    }
};

pub const KV = extern struct {
    key: Janet,
    value: Janet,

    pub fn toC(kv: *KV) [*c]c.JanetKV {
        return @ptrCast([*c]c.JanetKV, kv);
    }
};

pub const String = [*:0]const u8;
pub const Symbol = [*:0]const u8;
pub const Keyword = [*:0]const u8;
pub const Abstract = *c_void;

pub const StringHead = extern struct {
    gc: GCObject,
    length: i32,
    hash: i32,
    data: [*]const u8,
};

pub const GCObject = extern struct {
    flags: i32,
    blocks: extern union {
        next: *GCObject,
        refcount: i32,
    },
};

pub const Array = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    data: [*]Janet,

    pub fn toC(array: *Array) *c.JanetArray {
        return @ptrCast(*c.JanetArray, array);
    }

    pub fn fromC(janet_array: *c.JanetArray) *Array {
        return @ptrCast(*Array, janet_array);
    }
};

pub const Buffer = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    data: [*]u8,

    pub fn toC(buffer: *Buffer) *c.JanetBuffer {
        return @ptrCast(*c.JanetBuffer, buffer);
    }

    pub fn fromC(janet_buffer: *c.JanetBuffer) *Buffer {
        return @ptrCast(*Buffer, janet_buffer);
    }
};

pub const Tuple = struct {
    val: Type,

    pub const Type = []const Janet;
    pub const Head = extern struct {
        gc: GCObject,
        length: i32,
        hash: i32,
        sm_line: i32,
        sm_column: i32,
        data: [*]const Janet,
    };

    pub fn init(data: Type) Tuple {
        return Tuple{ .val = data };
    }

    pub fn head(tuple: Tuple) !*Head {
        const head = c.janet_tuple_head(@ptrCast(*const c.Janet, tuple.val.ptr));
        const aligned_head = @alignCast(@alignOf(*Head), head);
        return @ptrCast(*Head, aligned_head);
    }
};

pub const Struct = struct {
    ptr: Type,

    pub const Type = [*]const KV;
    pub const Head = extern struct {
        gc: GCObject,
        length: i32,
        hash: i32,
        capacity: i32,
        data: [*]const KV,
    };

    pub fn init(data: Type) Struct {
        return Struct{ .ptr = data };
    }

    pub fn head(st: Struct) !*Head {
        const head = c.janet_struct_head(@ptrCast(*const c.JanetKV, st.ptr.toC()));
        const aligned_head = @alignCast(@alignOf(*Head), head);
        return @ptrCast(*Head, aligned_head);
    }

    pub fn find(st: Struct, key: Janet) ?*const KV {
        return @ptrCast(?*const KV, c.janet_struct_find(st.toC(), key.toC()));
    }

    pub fn get(st: Struct, key: Janet) Janet {
        return Janet.fromC(c.janet_struct_get(st.toC(), key.toC()));
    }

    pub fn toC(st: Struct) [*c]const c.JanetKV {
        return @ptrCast([*]const c.JanetKV, st.ptr);
    }

    pub fn fromC(janet_st: *c.JanetStruct) *Table {
        return Struct.init(@ptrCast(Type, janet_st));
    }
};

pub const Table = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    deleted: i32,
    data: *KV,
    proto: *Table,

    pub fn toC(table: *Table) *c.JanetTable {
        return @ptrCast(*c.JanetTable, table);
    }

    pub fn fromC(janet_table: *c.JanetTable) *Table {
        return @ptrCast(*Table, janet_table);
    }

    pub fn find(table: *Table, key: Janet) ?*const KV {
        return @ptrCast(?*const KV, c.janet_table_find(table.toC(), key.toC()));
    }

    pub fn get(table: *Table, key: Janet) Janet {
        return Janet.fromC(c.janet_table_get(table.toC(), key.toC()));
    }
};

pub const MarshalContext = extern struct {
    m_state: *c_void,
    u_state: *c_void,
    flags: c_int,
    data: [*]const u8,
    at: *AbstractType,
};

pub const AbstractType = extern struct {
    name: [*:0]const u8,
    gc: ?fn (data: *c_void, len: usize) callconv(.C) c_int = null,
    gcmark: ?fn (data: *c_void, len: usize) callconv(.C) c_int = null,
    get: ?fn (data: *c_void, key: c.Janet, out: *c.Janet) callconv(.C) c_int = null,
    put: ?fn (data: *c_void, key: c.Janet, value: c.Janet) callconv(.C) void = null,
    marshal: ?fn (p: *c_void, ctx: *MarshalContext) callconv(.C) void = null,
    unmarshal: ?fn (ctx: *MarshalContext) callconv(.C) *c_void = null,
    tostring: ?fn (p: *c_void, buffer: *Buffer) callconv(.C) void = null,
    compare: ?fn (lhs: *c_void, rhs: *c_void) callconv(.C) c_int = null,
    hash: ?fn (p: *c_void, len: usize) callconv(.C) i32 = null,
    next: ?fn (p: *c_void, key: c.Janet) callconv(.C) Janet = null,
    call: ?fn (p: *c_void, argc: i32, argv: [*]Janet) callconv(.C) Janet = null,

    pub fn toC(at: *const AbstractType) *const c.JanetAbstractType {
        return @ptrCast(*const c.JanetAbstractType, at);
    }
};

pub const AbstractHead = extern struct {
    gc: GCObject,
    @"type": *AbstractType,
    size: usize,
    data: [*]c_longlong,
};

pub const Reg = extern struct {
    name: ?[*:0]const u8,
    cfun: ?CFunction,
    documentation: ?[*:0]const u8 = null,

    pub const empty = Reg{ .name = null, .cfun = null };
};

pub const RegExt = extern struct {
    name: ?[*:0]const u8,
    cfun: ?CFunction,
    documentation: ?[*:0]const u8 = null,
    source_file: ?[*:0]const u8 = null,
    source_line: i32 = 0,

    pub const empty = RegExt{ .name = null, .cfun = null };
};

pub const Method = extern struct {
    name: [*:0]const u8,
    cfun: CFunction,
};

pub const View = extern struct {
    items: [*]const Janet,
    len: i32,
};

pub const ByteView = extern struct {
    bytes: [*]const u8,
    len: i32,
};

pub const DictView = extern struct {
    kvs: [*]const KV,
    len: i32,
    cap: i32,
};

pub const Range = extern struct {
    start: i32,
    end: i32,
};

pub const RNG = extern struct {
    a: u32,
    b: u32,
    c: u32,
    d: u32,
    counter: u32,
};

pub const CFunction = fn (argc: i32, argv: [*]Janet) callconv(.C) Janet;

test "refAllDecls" {
    testing.refAllDecls(@This());
}

test "hello world" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    try dostring(env, "(prin `hello, world!`)", "main", null);
}

test "unwrap values" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    {
        var value: Janet = undefined;
        try dostring(env, "1", "main", &value);
        try testing.expectEqual(@as(i32, 1), try value.unwrapInteger());
    }
    {
        var value: Janet = undefined;
        try dostring(env, "1", "main", &value);
        try testing.expectEqual(@as(f64, 1), try value.unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try dostring(env, "true", "main", &value);
        try testing.expectEqual(true, try value.unwrapBoolean());
    }
    {
        var value: Janet = undefined;
        try dostring(env, "\"str\"", "main", &value);
        try testing.expectEqualStrings("str", try value.unwrapString());
    }
    {
        var value: Janet = undefined;
        try dostring(env, ":str", "main", &value);
        try testing.expectEqualStrings("str", try value.unwrapKeyword());
    }
    {
        var value: Janet = undefined;
        try dostring(env, "'str", "main", &value);
        try testing.expectEqualStrings("str", try value.unwrapSymbol());
    }
    {
        var value: Janet = undefined;
        try dostring(env, "[58 true 36.0]", "main", &value);
        const tuple = try value.unwrapTuple();
        try testing.expectEqual(@as(usize, 3), tuple.val.len);
        try testing.expectEqual(@as(i32, 58), try tuple.val[0].unwrapInteger());
        try testing.expectEqual(true, try tuple.val[1].unwrapBoolean());
        try testing.expectEqual(@as(f64, 36), try tuple.val[2].unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try dostring(env, "@[58 true 36.0]", "main", &value);
        const array = try value.unwrapArray();
        try testing.expectEqual(@as(i32, 3), array.count);
        try testing.expectEqual(@as(i32, 58), try array.data[0].unwrapInteger());
        try testing.expectEqual(true, try array.data[1].unwrapBoolean());
        try testing.expectEqual(@as(f64, 36), try array.data[2].unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try dostring(env, "@\"str\"", "main", &value);
        const buffer = try value.unwrapBuffer();
        try testing.expectEqual(@as(i32, 3), buffer.count);
        try testing.expectEqual(@as(u8, 's'), buffer.data[0]);
        try testing.expectEqual(@as(u8, 't'), buffer.data[1]);
        try testing.expectEqual(@as(u8, 'r'), buffer.data[2]);
    }
    {
        var value: Janet = undefined;
        try dostring(env, "{:kw 2 'sym 8 98 56}", "main", &value);
        _ = try value.unwrapStruct();
    }
    {
        var value: Janet = undefined;
        try dostring(env, "@{:kw 2 'sym 8 98 56}", "main", &value);
        _ = try value.unwrapTable();
    }
}

test "janet_type" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    var value: Janet = undefined;
    try dostring(env, "1", "main", &value);
    try testing.expectEqual(JanetType.number, value.janetType());
}

test "janet_checktypes" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    {
        var value: Janet = undefined;
        try dostring(env, "1", "main", &value);
        try testing.expectEqual(true, value.checktypes(TFLAG_NUMBER));
    }
    {
        var value: Janet = undefined;
        try dostring(env, ":str", "main", &value);
        try testing.expectEqual(true, value.checktypes(TFLAG_BYTES));
    }
}

test "struct" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    var value: Janet = undefined;
    try dostring(env, "{:kw 2 'sym 8 98 56}", "main", &value);
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

test "table" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    var value: Janet = undefined;
    try dostring(env, "@{:kw 2 'sym 8 98 56}", "main", &value);
    const table = try value.unwrapTable();
    const first_kv = table.get(keywordv("kw"));
    const second_kv = table.get(symbolv("sym"));
    const third_kv = table.get(wrapInteger(98));
    const none_kv = table.get(wrapInteger(123));
    try testing.expectEqual(@as(i32, 2), try first_kv.unwrapInteger());
    try testing.expectEqual(@as(i32, 8), try second_kv.unwrapInteger());
    try testing.expectEqual(@as(i32, 56), try third_kv.unwrapInteger());
    try testing.expectEqual(JanetType.nil, none_kv.janetType());
}

const ZigStruct = struct {
    counter: u32,

    pub const abstract_type = AbstractType{ .name = "zig-struct" };

    // Receives pointer to struct and argument
    pub fn inc(self: *ZigStruct, n: u32) void {
        self.counter += n;
    }
    // Can throw error
    pub fn dec(self: *ZigStruct) !void {
        if (self.counter == 0) return error.MustBeAboveZero;
        self.counter -= 1;
    }
};

/// Initializer with an optional default value for the `counter`.
fn cfunZigStruct(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    arity(argc, 0, 1);
    const stptr = abstract(&ZigStruct.abstract_type, @sizeOf(ZigStruct));
    const n = optNat(argv, 0, argc, 1);
    var st = fromPtr(*ZigStruct, stptr);
    st.counter = @intCast(u32, n);
    return wrapAbstract(stptr);
}

/// `inc` wrapper which receives a struct and a number to increase the `counter` to.
fn cfunInc(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 2);
    var stptr = getAbstract(argv, 0, &ZigStruct.abstract_type);
    const n = getNat(argv, 1);
    var st = fromPtr(*ZigStruct, stptr);
    st.inc(@intCast(u32, n));
    return wrapNil();
}

/// `dec` wrapper which fails if we try to decrease the `counter` below 0.
fn cfunDec(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    var stptr = getAbstract(argv, 0, &ZigStruct.abstract_type);
    var st = fromPtr(*ZigStruct, stptr);
    st.dec() catch {
        panic("expected failure, part of the test");
    };
    return wrapNil();
}

/// Simple getter returning an integer value.
fn cfunGetcounter(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    const stptr = getAbstract(argv, 0, &ZigStruct.abstract_type);
    const st = fromPtr(*ZigStruct, stptr);
    return wrapInteger(@bitCast(i32, st.counter));
}

const zig_struct_cfuns = [_]Reg{
    Reg{ .name = "struct-init", .cfun = cfunZigStruct },
    Reg{ .name = "inc", .cfun = cfunInc },
    Reg{ .name = "dec", .cfun = cfunDec },
    Reg{ .name = "get-counter", .cfun = cfunGetcounter },
    Reg.empty,
};

test "abstract" {
    try init();
    defer deinit();
    var env = coreEnv(null);
    cfunsPrefix(env, "zig", &zig_struct_cfuns);
    try dostring(env, "(def st (zig/struct-init))", "main", null);
    // Default value is 1 if not supplied with the initializer.
    try dostring(env, "(assert (= (zig/get-counter st) 1))", "main", null);
    try dostring(env, "(zig/dec st)", "main", null);
    try dostring(env, "(assert (= (zig/get-counter st) 0))", "main", null);
    // Expected fail of dec function.
    try testing.expectError(error.RuntimeError, dostring(env, "(zig/dec st)", "main", null));
    try dostring(env, "(assert (= (zig/get-counter st) 0))", "main", null);
    try dostring(env, "(zig/inc st 5)", "main", null);
    try dostring(env, "(assert (= (zig/get-counter st) 5))", "main", null);
}
