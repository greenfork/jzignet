const std = @import("std");
const testing = std.testing;

// Configuration

// TODO: check why this Janet implementation is broken here.
pub const JANET_NO_NANBOX = false;

pub const c = @cImport({
    if (JANET_NO_NANBOX) {
        @cDefine("JANET_NO_NANBOX", {});
    }
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

pub fn doString(env: *Table, str: [:0]const u8, source_path: [:0]const u8, out: ?*Janet) !void {
    return try doBytes(env, str, @intCast(i32, str.len), source_path, out);
}

pub fn doBytes(
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

pub fn keywordv(str: []const u8) Janet {
    return Janet.fromC(c.janet_keywordv(str.ptr, @intCast(i32, str.len)));
}
pub fn keyword(str: []const u8) Keyword {
    return Keyword.fromC(c.janet_keyword(str.ptr, @intCast(i32, str.len)));
}
pub fn symbolv(str: []const u8) Janet {
    return Janet.fromC(c.janet_symbolv(str.ptr, @intCast(i32, str.len)));
}
pub fn symbol(str: []const u8) Symbol {
    return Symbol.fromC(c.janet_symbol(str.ptr, @intCast(i32, str.len)));
}
pub fn stringv(str: []const u8) Janet {
    return Janet.fromC(c.janet_stringv(str.ptr, @intCast(i32, str.len)));
}
pub fn string(str: []const u8) String {
    return String.fromC(c.janet_string(str.ptr, @intCast(i32, str.len)));
}
pub fn abstract(
    comptime value_type: type,
    at: *const Abstract(value_type).Type,
) Abstract(value_type) {
    return Abstract(value_type).fromC(
        c.janet_abstract(at.toC(), @sizeOf(value_type)) orelse unreachable,
    );
}

pub fn symbolGen() Symbol {
    return Symbol.fromC(c.janet_symbol_gen());
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

pub fn getMethod(method: Keyword, methods: [*]const Method, out: *Janet) c_int {
    return c.janet_getmethod(
        method.toC(),
        @ptrCast([*c]const c.JanetMethod, methods),
        @ptrCast(*c.Janet, out),
    );
}
pub fn nextMethod(methods: [*]const Method, key: Janet) Janet {
    return Janet.fromC(c.janet_nextmethod(@ptrCast([*c]const c.JanetMethod, methods), key.toC()));
}

pub fn getNumber(argv: [*]const Janet, n: i32) f64 {
    return c.janet_getnumber(Janet.toCPtr(argv), n);
}
pub fn getArray(argv: [*]const Janet, n: i32) *Array {
    return Array.fromC(c.janet_getarray(Janet.toCPtr(argv), n));
}
pub fn getTuple(argv: [*]const Janet, n: i32) Tuple {
    return Tuple.fromC(c.janet_gettuple(Janet.toCPtr(argv), n));
}
pub fn getTable(argv: [*]const Janet, n: i32) *Table {
    return Table.fromC(c.janet_gettable(Janet.toCPtr(argv), n));
}
pub fn getStruct(argv: [*]const Janet, n: i32) Struct {
    return Struct.fromC(c.janet_getstruct(Janet.toCPtr(argv), n));
}
pub fn getString(argv: [*]const Janet, n: i32) String {
    return String.fromC(c.janet_getstring(Janet.toCPtr(argv), n));
}
pub fn getSymbol(argv: [*]const Janet, n: i32) Symbol {
    return Symbol.fromC(c.janet_getsymbol(Janet.toCPtr(argv), n));
}
pub fn getKeyword(argv: [*]const Janet, n: i32) Keyword {
    return Keyword.fromC(c.janet_getkeyword(Janet.toCPtr(argv), n));
}
pub fn getBuffer(argv: [*]const Janet, n: i32) *Buffer {
    return Buffer.fromC(c.janet_getbuffer(Janet.toCPtr(argv), n));
}
pub fn getBoolean(argv: [*]const Janet, n: i32) bool {
    return c.janet_getboolean(Janet.toCPtr(argv), n) > 0;
}
pub fn getPointer(argv: [*]const Janet, n: i32) *c_void {
    return c.janet_getpointer(Janet.toCPtr(argv), n) orelse unreachable;
}
pub fn getCFunction(argv: [*]const Janet, n: i32) CFunction {
    return @ptrCast(CFunction, c.janet_getcfunction(Janet.toCPtr(argv), n));
}
pub fn getFiber(argv: [*]const Janet, n: i32) *Fiber {
    return Fiber.fromC(c.janet_getfiber(Janet.toCPtr(argv), n) orelse unreachable);
}
pub fn getFunction(argv: [*]const Janet, n: i32) *Function {
    return Function.fromC(c.janet_getfunction(Janet.toCPtr(argv), n) orelse unreachable);
}
pub fn getNat(argv: [*]const Janet, n: i32) i32 {
    return c.janet_getnat(Janet.toCPtr(argv), n);
}
pub fn getInteger(argv: [*]const Janet, n: i32) i32 {
    return c.janet_getinteger(Janet.toCPtr(argv), n);
}
pub fn getInteger64(argv: [*]const Janet, n: i32) i64 {
    return c.janet_getinteger64(Janet.toCPtr(argv), n);
}
pub fn getSize(argv: [*]const Janet, n: i32) usize {
    return c.janet_getsize(Janet.toCPtr(argv), n);
}
pub fn getAbstract(
    argv: [*]const Janet,
    n: i32,
    comptime value_type: type,
    at: *const Abstract(value_type).Type,
) Abstract(value_type) {
    return Abstract(value_type).fromC(
        c.janet_getabstract(Janet.toCPtr(argv), n, at.toC()) orelse unreachable,
    );
}
pub fn getHalfRange(argv: [*]const Janet, n: i32, length: i32, which: [:0]const u8) i32 {
    return c.janet_gethalfrange(Janet.toCPtr(argv), n, length, which.ptr);
}
pub fn getArgIndex(argv: [*]const Janet, n: i32, length: i32, which: [:0]const u8) i32 {
    return c.janet_getargindex(Janet.toCPtr(argv), n, length, which.ptr);
}
pub fn getFlags(argv: [*]const Janet, n: i32, flags: [:0]const u8) u64 {
    return c.janet_getflags(Janet.toCPtr(argv), n, flags.ptr);
}
pub fn getIndexed(argv: [*]const Janet, n: i32) View {
    return @ptrCast(*View, &c.janet_getindexed(Janet.toCPtr(argv), n)).*;
}
pub fn getBytes(argv: [*]const Janet, n: i32) ByteView {
    return @ptrCast(*ByteView, &c.janet_getbytes(Janet.toCPtr(argv), n)).*;
}
pub fn getDictionary(argv: [*]const Janet, n: i32) DictView {
    return @ptrCast(*DictView, &c.janet_getdictionary(Janet.toCPtr(argv), n)).*;
}
pub fn getSlice(argc: i32, argv: [*]const Janet) Range {
    return @ptrCast(*Range, &c.janet_getslice(argc, Janet.toCPtr(argv))).*;
}

pub fn optNumber(argv: [*]const Janet, argc: i32, n: i32, dflt: f64) f64 {
    return c.janet_optnumber(Janet.toCPtr(argv), argc, n, dflt);
}
pub fn optTuple(argv: [*]const Janet, argc: i32, n: i32, dflt: Tuple) Tuple {
    return Tuple.fromC(c.janet_opttuple(Janet.toCPtr(argv), argc, n, dflt.toC()));
}
pub fn optStruct(argv: [*]const Janet, argc: i32, n: i32, dflt: Struct) Struct {
    return Struct.fromC(c.janet_optstruct(Janet.toCPtr(argv), argc, n, dflt.toC()));
}
pub fn optString(argv: [*]const Janet, argc: i32, n: i32, dflt: String) String {
    return String.fromC(c.janet_optstring(Janet.toCPtr(argv), argc, n, dflt.toC()));
}
pub fn optSymbol(argv: [*]const Janet, argc: i32, n: i32, dflt: Symbol) Symbol {
    return Symbol.fromC(c.janet_optsymbol(Janet.toCPtr(argv), argc, n, dflt.toC()));
}
pub fn optKeyword(argv: [*]const Janet, argc: i32, n: i32, dflt: Keyword) Keyword {
    return Keyword.fromC(c.janet_optkeyword(Janet.toCPtr(argv), argc, n, dflt.toC()));
}
pub fn optBoolean(argv: [*]const Janet, argc: i32, n: i32, dflt: bool) bool {
    return c.janet_optboolean(Janet.toCPtr(argv), argc, n, if (dflt) 1 else 0) > 0;
}
pub fn optPointer(argv: [*]const Janet, argc: i32, n: i32, dflt: *c_void) *c_void {
    return c.janet_optpointer(Janet.toCPtr(argv), argc, n, dflt) orelse unreachable;
}
pub fn optCFunction(argv: [*]const Janet, argc: i32, n: i32, dflt: CFunction) CFunction {
    return @ptrCast(CFunction, c.janet_optcfunction(
        Janet.toCPtr(argv),
        argc,
        n,
        @ptrCast(c.JanetCFunction, dflt),
    ));
}
pub fn optFiber(argv: [*]const Janet, argc: i32, n: i32, dflt: *Fiber) *Fiber {
    return Fiber.fromC(c.janet_optfiber(
        Janet.toCPtr(argv),
        argc,
        n,
        dflt.toC(),
    ) orelse unreachable);
}
pub fn optFunction(argv: [*]const Janet, argc: i32, n: i32, dflt: *Function) *Function {
    return Function.fromC(c.janet_optfunction(Janet.toCPtr(argv), argc, n, dflt.toC()) orelse unreachable);
}
pub fn optNat(argv: [*]const Janet, argc: i32, n: i32, dflt: i32) i32 {
    return c.janet_optnat(Janet.toCPtr(argv), argc, n, dflt);
}
pub fn optInteger(argv: [*]const Janet, argc: i32, n: i32, dflt: i32) i32 {
    return c.janet_optinteger(Janet.toCPtr(argv), argc, n, dflt);
}
pub fn optInteger64(argv: [*]const Janet, argc: i32, n: i32, dflt: i64) i64 {
    return c.janet_optinteger64(Janet.toCPtr(argv), argc, n, dflt);
}
pub fn optSize(argv: [*]const Janet, argc: i32, n: i32, dflt: usize) usize {
    return c.janet_optsize(Janet.toCPtr(argv), argc, n, dflt);
}
pub fn optAbstract(
    argv: [*]const Janet,
    argc: i32,
    n: i32,
    comptime value_type: type,
    at: *const Abstract(value_type).Type,
    dflt: Abstract(value_type),
) Abstract(value_type) {
    return c.janet_optabstract(
        Janet.toCPtr(argv),
        argc,
        n,
        at.toC(),
        dflt.toC(),
    ) orelse unreachable;
}
pub fn optArray(argv: [*]const Janet, argc: i32, n: i32, dflt_len: i32) *Array {
    return Array.fromC(c.janet_optarray(Janet.toCPtr(argv), argc, n, dflt_len));
}
pub fn optTable(argv: [*]const Janet, argc: i32, n: i32, dflt_len: i32) *Table {
    return Table.fromC(c.janet_opttable(Janet.toCPtr(argv), argc, n, dflt_len));
}
pub fn optBuffer(argv: [*]const Janet, argc: i32, n: i32, dflt_len: i32) *Buffer {
    return Buffer.fromC(c.janet_optbuffer(Janet.toCPtr(argv), argc, n, dflt_len));
}

pub fn wrapNil() Janet {
    return Janet.fromC(c.janet_wrap_nil());
}
pub fn wrapNumber(n: f64) Janet {
    return Janet.fromC(c.janet_wrap_number(n));
}
pub fn wrapTrue() Janet {
    return Janet.fromC(c.janet_wrap_true());
}
pub fn wrapFalse() Janet {
    return Janet.fromC(c.janet_wrap_false());
}
pub fn wrapBoolean(n: c_int) Janet {
    return Janet.fromC(c.janet_wrap_boolean(n));
}
pub fn wrapString(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_wrap_string(str.ptr));
}
pub fn wrapSymbol(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_wrap_symbol(str.ptr));
}
pub fn wrapKeyword(str: [:0]const u8) Janet {
    return Janet.fromC(c.janet_wrap_keyword(str.ptr));
}
pub fn wrapArray(x: *Array) Janet {
    return Janet.fromC(c.janet_wrap_array(x.toC()));
}
pub fn wrapTuple(x: Tuple) Janet {
    return Janet.fromC(c.janet_wrap_tuple(x.toC()));
}
pub fn wrapStruct(x: Struct) Janet {
    return Janet.fromC(c.janet_wrap_struct(x.toC()));
}
pub fn wrapFiber(x: *Fiber) Janet {
    return Janet.fromC(c.janet_wrap_fiber(x.toC()));
}
pub fn wrapBuffer(x: *Buffer) Janet {
    return Janet.fromC(c.janet_wrap_buffer(x.toC()));
}
pub fn wrapFunction(x: *Function) Janet {
    return Janet.fromC(c.janet_wrap_function(x.toC()));
}
pub fn wrapCFunction(x: CFunction) Janet {
    return Janet.fromC(c.janet_wrap_cfunction(@ptrCast(c.JanetCFunction, x)));
}
pub fn wrapTable(x: *Table) Janet {
    return Janet.fromC(c.janet_wrap_table(x.toC()));
}
pub fn wrapAbstract(x: *c_void) Janet {
    return Janet.fromC(c.janet_wrap_abstract(x));
}
pub fn wrapPointer(x: *c_void) Janet {
    return Janet.fromC(c.janet_wrap_pointer(x));
}
pub fn wrapInteger(n: i32) Janet {
    return Janet.fromC(c.janet_wrap_integer(n));
}

pub fn cfuns(env: *Table, reg_prefix: [:0]const u8, funs: [*]const Reg) void {
    return c.janet_cfuns(env.toC(), reg_prefix.ptr, @ptrCast([*c]const c.JanetReg, funs));
}
pub fn cfunsExt(env: *Table, reg_prefix: [:0]const u8, funs: [*]const RegExt) void {
    return c.janet_cfuns_ext(env.toC(), reg_prefix.ptr, @ptrCast([*c]const c.JanetRegExt, funs));
}
pub fn cfunsPrefix(env: *Table, reg_prefix: [:0]const u8, funs: [*]const Reg) void {
    return c.janet_cfuns_prefix(env.toC(), reg_prefix.ptr, @ptrCast([*c]const c.JanetReg, funs));
}
pub fn cfunsExtPrefix(env: *Table, reg_prefix: [:0]const u8, funs: [*]const RegExt) void {
    return c.janet_cfuns_ext_prefix(env.toC(), reg_prefix.ptr, @ptrCast([*c]const c.JanetRegExt, funs));
}

pub fn mark(x: Janet) void {
    c.janet_mark(x.toC());
}
pub fn sweep() void {
    c.janet_sweep();
}
pub fn collect() void {
    c.janet_collect();
}
pub fn clearMemory() void {
    c.janet_clear_memory();
}
pub fn gcRoot(root: Janet) void {
    c.janet_gcroot(root.toC());
}
pub fn gcUnroot(root: Janet) c_int {
    return c.janet_gcunroot(root.toC());
}
pub fn gcUnrootAll(root: Janet) c_int {
    return c.janet_gcunrootall(root.toC());
}
pub fn gcLock() c_int {
    return c.janet_gclock();
}
pub fn gcUnlock(handle: c_int) void {
    return c.janet_gcunlock(handle);
}
pub fn gcPressure(s: usize) void {
    c.janet_gcpressure(s);
}

pub const MARSHAL_UNSAFE = c.JANET_MARSHAL_UNSAFE;
pub fn marshal(buf: *Buffer, x: Janet, rreg: *Table, flags: c_int) void {
    c.janet_marshal(buf.toC(), x.toC(), rreg.toC(), flags);
}
pub fn unmarshal(bytes: []const u8, flags: c_int, reg: *Table, next: [*]*const u8) Janet {
    return Janet.fromC(c.janet_unmarshal(
        bytes.ptr,
        bytes.len,
        flags,
        reg.toC(),
        @ptrCast([*c][*c]const u8, next),
    ));
}
pub fn envLookup(env: *Table) *Table {
    return Table.fromC(c.janet_env_lookup(env.toC()));
}
pub fn envLookupInto(renv: *Table, env: *Table, prefix: [:0]const u8, recurse: c_int) void {
    c.janet_env_lookup_into(renv.toC(), env.toC(), prefix.ptr, recurse);
}
pub fn marshalSize(ctx: *MarshalContext, value: usize) void {
    c.janet_marshal_size(ctx.toC(), value);
}
pub fn marshalInt(ctx: *MarshalContext, value: i32) void {
    c.janet_marshal_int(ctx.toC(), value);
}
pub fn marshalInt64(ctx: *MarshalContext, value: i64) void {
    c.janet_marshal_int64(ctx.toC(), value);
}
pub fn marshalByte(ctx: *MarshalContext, value: u8) void {
    c.janet_marshal_byte(ctx.toC(), value);
}
pub fn marshalBytes(ctx: *MarshalContext, value: []const u8) void {
    c.janet_marshal_bytes(ctx.toC(), value.ptr, value.len);
}
pub fn marshalJanet(ctx: *MarshalContext, value: Janet) void {
    c.janet_marshal_janet(ctx.toC(), value.toC());
}
pub fn marshalAbstract(ctx: *MarshalContext, value: *c_void) void {
    c.janet_marshal_abstract(ctx.toC(), value);
}
pub fn unmarshalEnsure(ctx: *MarshalContext, size: usize) void {
    c.janet_unmarshal_ensure(ctx.toC(), size);
}
pub fn unmarshalSize(ctx: *MarshalContext) usize {
    return c.janet_unmarshal_size(ctx.toC());
}
pub fn unmarshalInt(ctx: *MarshalContext) i32 {
    return c.janet_unmarshal_int(ctx.toC());
}
pub fn unmarshalInt64(ctx: *MarshalContext) i64 {
    return c.janet_unmarshal_int64(ctx.toC());
}
pub fn unmarshalByte(ctx: *MarshalContext) u8 {
    return c.janet_unmarshal_byte(ctx.toC());
}
pub fn unmarshalBytes(ctx: *MarshalContext, dest: []u8) void {
    c.janet_unmarshal_bytes(ctx.toC(), dest.ptr, dest.len);
}
pub fn unmarshalJanet(ctx: *MarshalContext) Janet {
    return Janet.fromC(c.janet_unmarshal_janet(ctx.toC()));
}
pub fn unmarshalAbstract(ctx: *MarshalContext, size: usize) *c_void {
    return c.janet_unmarshal_abstract(ctx.toC(), size) orelse unreachable;
}
pub fn unmarshalAbstractReuse(ctx: *MarshalContext, p: *c_void) void {
    c.janet_unmarshal_abstract_reuse(ctx.toC(), p);
}
pub fn registerAbstractType(at: *const AbstractType) void {
    c.janet_register_abstract_type(at.toC());
}
pub fn getAbstractType(key: Janet) *const AbstractType {
    return AbstractType.fromC(c.janet_get_abstract_type(key.toC()));
}

pub fn malloc(size: usize) ?*c_void {
    return c.janet_malloc(size);
}
pub fn realloc(ptr: *c_void, size: usize) ?*c_void {
    return c.janet_realloc(ptr, size);
}
pub fn calloc(nmemb: usize, size: usize) ?*c_void {
    return c.janet_calloc(nmemb, size);
}
pub fn free(ptr: *c_void) void {
    c.janet_free(ptr);
}

const JanetType = enum(c_int) {
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
    if (JANET_NO_NANBOX or
        std.builtin.target.cpu.arch.isARM() or
        std.builtin.target.cpu.arch == .aarch64)
    {
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
    } else if (std.builtin.target.cpu.arch == .x86_64) {
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
    }
};

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
        if (!janet.checkType(.number)) return error.NotNumber;
        return c.janet_unwrap_integer(janet.toC());
    }
    pub fn unwrapNumber(janet: Janet) !f64 {
        if (!janet.checkType(.number)) return error.NotNumber;
        return c.janet_unwrap_number(janet.toC());
    }
    pub fn unwrapBoolean(janet: Janet) !bool {
        if (!janet.checkType(.boolean)) return error.NotBoolean;
        return c.janet_unwrap_boolean(janet.toC()) > 0;
    }
    pub fn unwrapString(janet: Janet) !String {
        if (!janet.checkType(.string)) return error.NotString;
        return String.fromC(c.janet_unwrap_string(janet.toC()));
    }
    pub fn unwrapKeyword(janet: Janet) !Keyword {
        if (!janet.checkType(.keyword)) return error.NotKeyword;
        return Keyword.fromC(c.janet_unwrap_keyword(janet.toC()));
    }
    pub fn unwrapSymbol(janet: Janet) !Symbol {
        if (!janet.checkType(.symbol)) return error.NotSymbol;
        return Symbol.fromC(c.janet_unwrap_symbol(janet.toC()));
    }
    pub fn unwrapTuple(janet: Janet) !Tuple {
        if (!janet.checkType(.tuple)) return error.NotTuple;
        return Tuple.fromC(c.janet_unwrap_tuple(janet.toC()));
    }
    pub fn unwrapArray(janet: Janet) !*Array {
        if (!janet.checkType(.array)) return error.NotArray;
        return @ptrCast(*Array, c.janet_unwrap_array(janet.toC()));
    }
    pub fn unwrapBuffer(janet: Janet) !*Buffer {
        if (!janet.checkType(.buffer)) return error.NotBuffer;
        return @ptrCast(*Buffer, c.janet_unwrap_buffer(janet.toC()));
    }
    pub fn unwrapStruct(janet: Janet) !Struct {
        if (!janet.checkType(.@"struct")) return error.NotStruct;
        return Struct.fromC(c.janet_unwrap_struct(janet.toC()));
    }
    pub fn unwrapTable(janet: Janet) !*Table {
        if (!janet.checkType(.table)) return error.NotTable;
        return @ptrCast(*Table, c.janet_unwrap_table(janet.toC()));
    }
    pub fn unwrapPointer(janet: Janet) !*c_void {
        if (!janet.checkType(.pointer)) return error.NotPointer;
        return c.janet_unwrap_pointer(janet.toC()) orelse unreachable;
    }
    pub fn unwrapCFunction(janet: Janet) !CFunction {
        if (!janet.checkType(.cfunction)) return error.NotCFunction;
        return @ptrCast(CFunction, c.janet_unwrap_cfunction(janet.toC()));
    }
    pub fn unwrapFunction(janet: Janet) !*Function {
        if (!janet.checkType(.function)) return error.NotFunction;
        return Function.fromC(c.janet_unwrap_function(janet.toC()) orelse unreachable);
    }
    pub fn unwrapAbstract(janet: Janet, comptime value_type: type) !Abstract(value_type) {
        if (!janet.checkType(.abstract)) return error.NotAbstract;
        return Abstract(value_type).fromC(c.janet_unwrap_abstract(janet.toC()) orelse unreachable);
    }
    pub fn unwrapFiber(janet: Janet) !*Fiber {
        if (!janet.checkType(.fiber)) return error.NotFiber;
        return Fiber.fromC(c.janet_unwrap_fiber(janet.toC()) orelse unreachable);
    }

    pub fn checkType(janet: Janet, typ: JanetType) bool {
        return c.janet_checktype(janet.toC(), @ptrCast(*const c.JanetType, &typ).*) > 0;
    }
    pub fn checkTypes(janet: Janet, typeflags: i32) bool {
        return c.janet_checktypes(janet.toC(), typeflags) > 0;
    }
    pub fn truthy(janet: Janet) bool {
        return c.janet_truthy(janet.toC()) > 0;
    }
    pub fn janetType(janet: Janet) JanetType {
        return @ptrCast(*JanetType, &c.janet_type(janet.toC())).*;
    }
};

pub const KV = extern struct {
    key: Janet,
    value: Janet,

    pub fn toC(self: *KV) [*c]c.JanetKV {
        return @ptrCast([*c]c.JanetKV, self);
    }
};

pub const String = struct {
    slice: TypeImpl,

    pub const TypeImpl = [:0]const u8;
    pub const TypeC = [*:0]const u8;
    pub const Head = extern struct {
        gc: GCObject,
        length: i32,
        hash: i32,
        data: [*]const u8,
    };

    pub fn toC(self: String) TypeC {
        return self.slice.ptr;
    }
    pub fn fromC(ptr: TypeC) String {
        return String{ .slice = std.mem.span(ptr) };
    }

    pub fn head(self: Tuple) !*Head {
        const h = c.janet_string_head(self.slice.ptr);
        const aligned_head = @alignCast(@alignOf(*Head), h);
        return @ptrCast(*Head, aligned_head);
    }
};

pub const Symbol = struct {
    slice: TypeImpl,

    pub const TypeImpl = [:0]const u8;
    pub const TypeC = [*:0]const u8;

    pub fn toC(self: Symbol) TypeC {
        return self.slice.ptr;
    }
    pub fn fromC(ptr: TypeC) Symbol {
        return Symbol{ .slice = std.mem.span(ptr) };
    }
};

pub const Keyword = struct {
    slice: TypeImpl,

    pub const TypeImpl = [:0]const u8;
    pub const TypeC = [*:0]const u8;

    pub fn toC(self: Keyword) TypeC {
        return self.slice.ptr;
    }
    pub fn fromC(ptr: TypeC) Keyword {
        return Keyword{ .slice = std.mem.span(ptr) };
    }
};

pub const Array = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    data: [*]Janet,

    pub fn toC(self: *Array) *c.JanetArray {
        return @ptrCast(*c.JanetArray, self);
    }
    pub fn fromC(ptr: *c.JanetArray) *Array {
        return @ptrCast(*Array, ptr);
    }
};

pub const Buffer = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    data: [*]u8,

    pub fn toC(self: *Buffer) *c.JanetBuffer {
        return @ptrCast(*c.JanetBuffer, self);
    }
    pub fn fromC(ptr: *c.JanetBuffer) *Buffer {
        return @ptrCast(*Buffer, ptr);
    }

    /// C function: janet_buffer_init
    pub fn init(janet: Janet, capacity: i32) *Buffer {
        return fromC(c.janet_buffer_init(janet.toC(), capacity));
    }
    /// C function: janet_buffer
    pub fn initDynamic(capacity: i32) *Buffer {
        return fromC(c.janet_buffer(capacity));
    }
    pub fn deinit(self: *Buffer) void {
        c.janet_buffer_deinit(self.toC());
    }
    pub fn ensure(self: *Buffer, capacity: i32, growth: i32) void {
        c.janet_buffer_ensure(self.toC(), capacity, growth);
    }
    pub fn setCount(self: *Buffer, count: i32) void {
        c.janet_buffer_setcount(self.toC(), count);
    }
    pub fn extra(self: *Buffer, n: i32) void {
        c.janet_buffer_extra(self.toC(), n);
    }
    pub fn pushBytes(self: *Buffer, bytes: []const u8) void {
        c.janet_buffer_push_bytes(self.toC(), bytes.ptr, @intCast(i32, bytes.len));
    }
    pub fn pushString(self: *Buffer, string: Janet) void {
        c.janet_buffer_push_string(self.toC(), string.toC());
    }
    pub fn pushU8(self: *Buffer, x: u8) void {
        c.janet_buffer_push_u8(self.toC(), x);
    }
    pub fn pushU16(self: *Buffer, x: u16) void {
        c.janet_buffer_push_u16(self.toC(), x);
    }
    pub fn pushU32(self: *Buffer, x: u32) void {
        c.janet_buffer_push_u32(self.toC(), x);
    }
    pub fn pushU64(self: *Buffer, x: u64) void {
        c.janet_buffer_push_u64(self.toC(), x);
    }
};

pub const Tuple = struct {
    slice: TypeImpl,

    pub const TypeImpl = []const Janet;
    pub const TypeC = [*c]const c.Janet;
    pub const Head = extern struct {
        gc: GCObject,
        length: i32,
        hash: i32,
        sm_line: i32,
        sm_column: i32,
        data: [*]const Janet,
    };

    pub fn fromC(ptr: TypeC) Tuple {
        const p = @ptrCast([*]const Janet, ptr);
        const janet_head = c.janet_tuple_head(ptr);
        const h = @ptrCast(*Head, @alignCast(@alignOf(*Head), janet_head));
        const len = @intCast(usize, h.length);
        return Tuple{ .slice = p[0..len] };
    }
    pub fn toC(self: Tuple) TypeC {
        return @ptrCast(TypeC, self.slice.ptr);
    }

    pub fn head(self: Tuple) !*Head {
        const h = c.janet_tuple_head(@ptrCast(*const c.Janet, self.slice.ptr));
        const aligned_head = @alignCast(@alignOf(*Head), h);
        return @ptrCast(*Head, aligned_head);
    }
};

pub const Struct = struct {
    ptr: TypeImpl,

    pub const TypeImpl = [*]const KV;
    pub const TypeC = [*c]const c.JanetKV;
    pub const Head = extern struct {
        gc: GCObject,
        length: i32,
        hash: i32,
        capacity: i32,
        data: [*]const KV,
    };

    pub fn toC(self: Struct) TypeC {
        return @ptrCast([*]const c.JanetKV, self.ptr);
    }
    pub fn fromC(ptr: TypeC) Struct {
        return Struct{ .ptr = @ptrCast(TypeImpl, ptr) };
    }

    pub fn head(self: Struct) !*Head {
        const h = c.janet_struct_head(@ptrCast(*const c.JanetKV, self.toC()));
        const aligned_head = @alignCast(@alignOf(*Head), h);
        return @ptrCast(*Head, aligned_head);
    }

    pub fn find(self: Struct, key: Janet) ?*const KV {
        return @ptrCast(?*const KV, c.janet_struct_find(self.toC(), key.toC()));
    }

    pub fn get(self: Struct, key: Janet) Janet {
        return Janet.fromC(c.janet_struct_get(self.toC(), key.toC()));
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

    pub fn find(self: *Table, key: Janet) ?*const KV {
        return @ptrCast(?*const KV, c.janet_self_find(self.toC(), key.toC()));
    }

    pub fn get(self: *Table, key: Janet) Janet {
        return Janet.fromC(c.janet_table_get(self.toC(), key.toC()));
    }
};

pub const GCObject = extern struct {
    flags: i32,
    blocks: extern union {
        next: *GCObject,
        refcount: i32,
    },
};

pub const Function = extern struct {
    gc: GCObject,
    def: *Def,
    envs: [*]*Env,

    pub const Def = extern struct {
        gc: GCObject,
        environments: [*]i32,
        constants: [*]Janet,
        defs: [*]*Def,
        bytecode: [*]u32,
        closure_bitset: [*]u32,

        sourcemap: *SourceMapping,
        source: String.TypeC,
        name: String.TypeC,

        flags: i32,
        slot_count: i32,
        arity: i32,
        min_arity: i32,
        max_arity: i32,
        constants_length: i32,
        bytecode_length: i32,
        environments_length: i32,
        defs_length: i32,
    };
    pub const Env = extern struct {
        gc: GCObject,
        as: extern union {
            fiber: *Fiber,
            values: [*]Janet,
        },
        length: i32,
        offset: i32,
    };

    pub fn toC(self: *Function) *c.JanetFunction {
        return @ptrCast(*c.JanetFunction, self);
    }
    pub fn fromC(ptr: *c.JanetFunction) *Function {
        return @ptrCast(*Function, @alignCast(@alignOf(*Function), ptr));
    }
};

pub const Fiber = extern struct {
    gc: GCObject,
    flags: i32,
    frame: i32,
    stack_start: i32,
    stack_stop: i32,
    capacity: i32,
    max_stack: i32,
    env: *Table,
    data: [*]Janet,
    child: *Fiber,
    last_value: Janet,
    // #ifdef JANET_EV
    waiting: *ListenerState,
    sched_id: i32,
    supervisor_channel: *c_void,

    pub fn toC(self: *Fiber) *c.JanetFiber {
        return @ptrCast(*c.JanetFiber, self);
    }
    pub fn fromC(ptr: *c.JanetFiber) *Fiber {
        return @ptrCast(*Fiber, ptr);
    }
};

pub const ListenerState = blk: {
    if (std.builtin.target.os.tag == .windows) {
        break :blk extern struct {
            machine: Listener,
            fiber: *Fiber,
            stream: *Stream,
            event: *c_void,
            tag: *c_void,
            bytes: c_int,
        };
    } else {
        break :blk extern struct {
            machine: Listener,
            fiber: *Fiber,
            stream: *Stream,
            event: *c_void,
            _index: usize,
            _mask: c_int,
            _next: *ListenerState,
        };
    }
};

pub const Handle = blk: {
    if (std.builtin.target.os.tag == .windows) {
        break :blk *c_void;
    } else {
        break :blk c_int;
    }
};

pub const HANDLE_NONE: Handle = blk: {
    if (std.builtin.target.os.tag == .windows) {
        break :blk null;
    } else {
        break :blk -1;
    }
};

pub const Stream = extern struct {
    handle: Handle,
    flags: u32,
    state: *ListenerState,
    methods: *const c_void,
    _mask: c_int,
};

pub const Listener = fn (state: *ListenerState, event: AsyncEvent) callconv(.C) AsyncStatus;

pub const AsyncStatus = enum(c_int) {
    not_done,
    done,
};

pub const AsyncEvent = enum(c_int) {
    init,
    mark,
    deinit,
    close,
    err,
    hup,
    read,
    write,
    cancel,
    complete,
    user,
};

pub const SourceMapping = extern struct {
    line: i32,
    column: i32,
};

pub const MarshalContext = extern struct {
    m_state: *c_void,
    u_state: *c_void,
    flags: c_int,
    data: [*]const u8,
    at: *AbstractType,

    pub fn toC(mc: *MarshalContext) *c.JanetMarshalContext {
        return @ptrCast(*c.JanetMarshalContext, mc);
    }
    pub fn fromC(mc: *c.JanetMarshalContext) *MarshalContext {
        return @ptrCast(*MarshalContext, mc);
    }
};

/// Specialized struct with typed pointers. `value_type` must be the type of the actual value,
/// not the pointer to the value, for example, for direct C translation of `*c_void`, `value_type`
/// must be `c_void`.
pub fn Abstract(comptime value_type: type) type {
    return struct {
        ptr: *value_type,

        const Self = @This();
        pub const Head = extern struct {
            gc: GCObject,
            @"type": *Type,
            size: usize,
            data: [*]c_longlong,
        };
        pub const Type = extern struct {
            name: [*:0]const u8,
            gc: ?fn (p: *value_type, len: usize) callconv(.C) c_int = null,
            gc_mark: ?fn (p: *value_type, len: usize) callconv(.C) c_int = null,
            get: ?fn (p: *value_type, key: Janet, out: *Janet) callconv(.C) c_int = null,
            put: ?fn (p: *value_type, key: Janet, value: Janet) callconv(.C) void = null,
            marshal: ?fn (p: *value_type, ctx: *MarshalContext) callconv(.C) void = null,
            unmarshal: ?fn (ctx: *MarshalContext) callconv(.C) *value_type = null,
            to_string: ?fn (p: *value_type, buffer: *Buffer) callconv(.C) void = null,
            compare: ?fn (lhs: *value_type, rhs: *value_type) callconv(.C) c_int = null,
            hash: ?fn (p: *value_type, len: usize) callconv(.C) i32 = null,
            next: ?fn (p: *value_type, key: Janet) callconv(.C) Janet = null,
            call: ?fn (p: *value_type, argc: i32, argv: [*]Janet) callconv(.C) Janet = null,

            pub fn toC(self: *const Type) *const c.JanetAbstractType {
                return @ptrCast(*const c.JanetAbstractType, self);
            }
            pub fn fromC(p: *const c.JanetAbstractType) *const Type {
                return @ptrCast(*const Type, p);
            }
            pub fn toVoid(self: *const Type) *const Abstract(c_void).Type {
                return @ptrCast(*const Abstract(c_void).Type, self);
            }

            pub fn register(self: *const Type) void {
                c.janet_register_abstract_type(self.toC());
            }
        };

        pub fn toC(self: Self) *c_void {
            return @ptrCast(*c_void, self.ptr);
        }
        pub fn fromC(p: *c_void) Self {
            return Self{ .ptr = @ptrCast(*value_type, @alignCast(@alignOf(*value_type), p)) };
        }
        pub fn fromPtr(v: *value_type) Self {
            return Self{ .ptr = v };
        }

        pub fn wrap(self: Self) Janet {
            return Janet.fromC(c.janet_wrap_abstract(self.toC()));
        }
        pub fn marshal(self: Self, ctx: *MarshalContext) void {
            c.janet_marshal_abstract(ctx.toC(), self.toC());
        }
        pub fn unmarshal(ctx: *MarshalContext) Self {
            return fromC(
                c.janet_unmarshal_abstract(ctx.toC(), @sizeOf(value_type)) orelse unreachable,
            );
        }
    };
}

pub const VoidAbstract = Abstract(c_void);

/// Pure translation of a C struct with pointers *c_void.
pub const AbstractType = VoidAbstract.Type;

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
    try doString(env, "(prin `hello, world!`)", "main", null);
}

test "unwrap values" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    {
        var value: Janet = undefined;
        try doString(env, "1", "main", &value);
        try testing.expectEqual(@as(i32, 1), try value.unwrapInteger());
    }
    {
        var value: Janet = undefined;
        try doString(env, "1", "main", &value);
        try testing.expectEqual(@as(f64, 1), try value.unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try doString(env, "true", "main", &value);
        try testing.expectEqual(true, try value.unwrapBoolean());
    }
    {
        var value: Janet = undefined;
        try doString(env, "\"str\"", "main", &value);
        try testing.expectEqualStrings("str", (try value.unwrapString()).slice);
    }
    {
        var value: Janet = undefined;
        try doString(env, ":str", "main", &value);
        try testing.expectEqualStrings("str", (try value.unwrapKeyword()).slice);
    }
    {
        var value: Janet = undefined;
        try doString(env, "'str", "main", &value);
        try testing.expectEqualStrings("str", (try value.unwrapSymbol()).slice);
    }
    {
        var value: Janet = undefined;
        try doString(env, "[58 true 36.0]", "main", &value);
        const tuple = try value.unwrapTuple();
        try testing.expectEqual(@as(i32, 3), (try tuple.head()).length);
        try testing.expectEqual(@as(usize, 3), tuple.slice.len);
        try testing.expectEqual(@as(i32, 58), try tuple.slice[0].unwrapInteger());
        try testing.expectEqual(true, try tuple.slice[1].unwrapBoolean());
        try testing.expectEqual(@as(f64, 36), try tuple.slice[2].unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try doString(env, "@[58 true 36.0]", "main", &value);
        const array = try value.unwrapArray();
        try testing.expectEqual(@as(i32, 3), array.count);
        try testing.expectEqual(@as(i32, 58), try array.data[0].unwrapInteger());
        try testing.expectEqual(true, try array.data[1].unwrapBoolean());
        try testing.expectEqual(@as(f64, 36), try array.data[2].unwrapNumber());
    }
    {
        var value: Janet = undefined;
        try doString(env, "@\"str\"", "main", &value);
        const buffer = try value.unwrapBuffer();
        try testing.expectEqual(@as(i32, 3), buffer.count);
        try testing.expectEqual(@as(u8, 's'), buffer.data[0]);
        try testing.expectEqual(@as(u8, 't'), buffer.data[1]);
        try testing.expectEqual(@as(u8, 'r'), buffer.data[2]);
    }
    {
        var value: Janet = undefined;
        try doString(env, "{:kw 2 'sym 8 98 56}", "main", &value);
        _ = try value.unwrapStruct();
    }
    {
        var value: Janet = undefined;
        try doString(env, "@{:kw 2 'sym 8 98 56}", "main", &value);
        _ = try value.unwrapTable();
    }
    {
        var value: Janet = undefined;
        try doString(env, "marshal", "main", &value);
        _ = try value.unwrapCFunction();
    }
    {
        var value: Janet = undefined;
        try doString(env, "+", "main", &value);
        _ = try value.unwrapFunction();
    }
    {
        var value: Janet = undefined;
        try doString(env, "(file/temp)", "main", &value);
        _ = try value.unwrapAbstract(c_void);
    }
    {
        var value: Janet = undefined;
        try doString(env, "(fiber/current)", "main", &value);
        _ = try value.unwrapFiber();
    }
}

test "janet_type" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    var value: Janet = undefined;
    try doString(env, "1", "main", &value);
    try testing.expectEqual(JanetType.number, value.janetType());
}

test "janet_checktypes" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    {
        var value: Janet = undefined;
        try doString(env, "1", "main", &value);
        try testing.expectEqual(true, value.checkTypes(TFLAG_NUMBER));
    }
    {
        var value: Janet = undefined;
        try doString(env, ":str", "main", &value);
        try testing.expectEqual(true, value.checkTypes(TFLAG_BYTES));
    }
}

test "struct" {
    try init();
    defer deinit();
    const env = coreEnv(null);
    var value: Janet = undefined;
    try doString(env, "{:kw 2 'sym 8 98 56}", "main", &value);
    const st = try value.unwrapStruct();
    const first_kv = st.get(keywordv("kw"));
    const second_kv = st.get(symbolv("sym"));
    const third_kv = st.get(wrapInteger(98));
    const none_kv = st.get(wrapInteger(123));
    try testing.expectEqual(@as(i32, 3), (try st.head()).length);
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
    try doString(env, "@{:kw 2 'sym 8 98 56}", "main", &value);
    const table = try value.unwrapTable();
    const first_kv = table.get(keywordv("kw"));
    const second_kv = table.get(symbolv("sym"));
    const third_kv = table.get(wrapInteger(98));
    const none_kv = table.get(wrapInteger(123));
    try testing.expectEqual(@as(i32, 3), table.count);
    try testing.expectEqual(@as(i32, 2), try first_kv.unwrapInteger());
    try testing.expectEqual(@as(i32, 8), try second_kv.unwrapInteger());
    try testing.expectEqual(@as(i32, 56), try third_kv.unwrapInteger());
    try testing.expectEqual(JanetType.nil, none_kv.janetType());
}

const ZigStruct = struct {
    counter: u32,

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

const ZigStructAbstract = Abstract(ZigStruct);
const zig_struct_abstract_type = ZigStructAbstract.Type{ .name = "zig-struct" };

/// Initializer with an optional default value for the `counter`.
fn cfunZigStruct(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    arity(argc, 0, 1);
    const st_abstract = abstract(ZigStruct, &zig_struct_abstract_type);
    const n = optNat(argv, 0, argc, 1);
    st_abstract.ptr.counter = @intCast(u32, n);
    return st_abstract.wrap();
}

/// `inc` wrapper which receives a struct and a number to increase the `counter` to.
fn cfunInc(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 2);
    var st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    const n = getNat(argv, 1);
    st_abstract.ptr.inc(@intCast(u32, n));
    return wrapNil();
}

/// `dec` wrapper which fails if we try to decrease the `counter` below 0.
fn cfunDec(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    var st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    st_abstract.ptr.dec() catch {
        panic("expected failure, part of the test");
    };
    return wrapNil();
}

/// Simple getter returning an integer value.
fn cfunGetcounter(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    const st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    return wrapInteger(@bitCast(i32, st_abstract.ptr.counter));
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
    try doString(env, "(def st (zig/struct-init))", "main", null);
    // Default value is 1 if not supplied with the initializer.
    try doString(env, "(assert (= (zig/get-counter st) 1))", "main", null);
    try doString(env, "(zig/dec st)", "main", null);
    try doString(env, "(assert (= (zig/get-counter st) 0))", "main", null);
    // Expected fail of dec function.
    try testing.expectError(error.RuntimeError, doString(env, "(zig/dec st)", "main", null));
    try doString(env, "(assert (= (zig/get-counter st) 0))", "main", null);
    try doString(env, "(zig/inc st 5)", "main", null);
    try doString(env, "(assert (= (zig/get-counter st) 5))", "main", null);
}

// We need an allocator to pass to the Zig struct.
const AllyAbstractType = Abstract(*std.mem.Allocator).Type{ .name = "zig-allocator" };

/// Initializer to make Zig's allocator into existence.
fn cfunInitZigAllocator(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 0);
    const ally_abstract = abstract(*std.mem.Allocator, &AllyAbstractType);
    // This will have to be a global definition of an allocator, otherwise it is impossible
    // to get one inside this function. Here we are fine since `testing` has a global allocator.
    ally_abstract.ptr.* = testing.allocator;
    return ally_abstract.wrap();
}

// With all the possible functions.
const ComplexZigStruct = struct {
    counter: i32,
    // Storing native to Janet values in Zig data structure.
    storage: std.StringHashMap(Janet),

    // It needs to be initialized first with the Zig's allocator.
    pub fn init(ally: *std.mem.Allocator) ComplexZigStruct {
        return ComplexZigStruct{
            .counter = 0,
            .storage = std.StringHashMap(Janet).init(ally),
        };
    }
    pub fn deinit(self: *ComplexZigStruct) void {
        self.storage.deinit();
    }
};

fn czsGc(st: *ComplexZigStruct, len: usize) callconv(.C) c_int {
    _ = len;
    st.deinit();
    return 0;
}
fn czsGcMark(st: *ComplexZigStruct, len: usize) callconv(.C) c_int {
    _ = len;
    var it = st.storage.valueIterator();
    while (it.next()) |value| {
        mark(value.*);
    }
    return 0;
}
fn czsGet(st: *ComplexZigStruct, key: Janet, out: *Janet) callconv(.C) c_int {
    const k = key.unwrapKeyword() catch {
        panic("Not a keyword");
    };
    if (st.storage.get(k.slice)) |value| {
        out.* = value;
        return 1;
    } else {
        return 0;
    }
}
fn czsPut(st: *ComplexZigStruct, key: Janet, value: Janet) callconv(.C) void {
    const k = key.unwrapKeyword() catch {
        panic("Not a keyword");
    };
    // HACK: allocating the key to be stored in our struct's `storage` via Janet's allocation
    // function which is never freed. I'm too lazy to implement allocating and deallocating of
    // strings via Zig's allocator, sorry.
    var allocated_key = @ptrCast(
        [*]u8,
        @alignCast(@alignOf([*]u8), malloc(k.slice.len)),
    )[0..k.slice.len];
    std.mem.copy(u8, allocated_key, k.slice);
    st.storage.put(allocated_key, value) catch {
        panic("Out of memory");
    };
}
// We only marshal the counter, the `storage` is lost, as well as allocator.
fn czsMarshal(st: *ComplexZigStruct, ctx: *MarshalContext) callconv(.C) void {
    var ally = st.storage.allocator;
    Abstract(ComplexZigStruct).fromPtr(st).marshal(ctx);
    // HACK: we can't marshal more than one abstract type, so we marshal the pointer as integer
    // since the allocator is global and will not change its pointer during program execution.
    marshalSize(ctx, @ptrToInt(&ally));
    marshalInt(ctx, st.counter);
}
fn czsUnmarshal(ctx: *MarshalContext) callconv(.C) *ComplexZigStruct {
    const st_abstract = Abstract(ComplexZigStruct).unmarshal(ctx);
    const allyp = unmarshalSize(ctx);
    const ally = @intToPtr(**std.mem.Allocator, allyp);
    const counter = unmarshalInt(ctx);
    st_abstract.ptr.counter = counter;
    st_abstract.ptr.storage = std.StringHashMap(Janet).init(ally.*);
    return st_abstract.ptr;
}
fn czsToString(st: *ComplexZigStruct, buffer: *Buffer) callconv(.C) void {
    _ = st;
    buffer.pushBytes("complex-zig-struct-printing");
}
fn czsCompare(lhs: *ComplexZigStruct, rhs: *ComplexZigStruct) callconv(.C) c_int {
    if (lhs.counter > rhs.counter) {
        return 1;
    } else if (lhs.counter < rhs.counter) {
        return -1;
    } else {
        return 0;
    }
}
fn czsHash(st: *ComplexZigStruct, len: usize) callconv(.C) i32 {
    _ = st;
    _ = len;
    return 1337;
}
fn czsNext(st: *ComplexZigStruct, key: Janet) callconv(.C) Janet {
    if (key.checkType(.nil)) {
        var it = st.storage.keyIterator();
        if (it.next()) |next_key| {
            return keywordv(next_key.*);
        } else {
            return wrapNil();
        }
    } else {
        const str_key = key.unwrapKeyword() catch {
            panic("Not a keyword");
        };
        var it = st.storage.keyIterator();
        while (it.next()) |k| {
            if (std.mem.eql(u8, k.*, str_key.slice)) {
                if (it.next()) |next_key| {
                    return keywordv(next_key.*);
                } else {
                    return wrapNil();
                }
            }
        } else {
            return wrapNil();
        }
    }
    unreachable;
}
// We set the counter to the supplied value.
fn czsCall(st: *ComplexZigStruct, argc: i32, argv: [*]Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    const new_counter = getInteger(argv, 0);
    st.counter = new_counter;
    return wrapTrue();
}

const complex_zig_struct_abstract_type = Abstract(ComplexZigStruct).Type{
    .name = "complex-zig-struct",
    .gc = czsGc,
    .gc_mark = czsGcMark,
    .get = czsGet,
    .put = czsPut,
    .marshal = czsMarshal,
    .unmarshal = czsUnmarshal,
    .to_string = czsToString,
    .compare = czsCompare,
    .hash = czsHash,
    .next = czsNext,
    .call = czsCall,
};

/// Initializer with an optional default value for the `counter`.
fn cfunComplexZigStruct(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    const st_abstract = abstract(ComplexZigStruct, &complex_zig_struct_abstract_type);
    const ally_abstract = getAbstract(argv, 0, *std.mem.Allocator, &AllyAbstractType);
    st_abstract.ptr.* = ComplexZigStruct.init(ally_abstract.ptr.*);
    return st_abstract.wrap();
}
/// Simple getter returning an integer value.
fn cfunGetComplexCounter(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    const st_abstract = getAbstract(argv, 0, ComplexZigStruct, &complex_zig_struct_abstract_type);
    return wrapInteger(st_abstract.ptr.counter);
}

const complex_zig_struct_cfuns = [_]Reg{
    Reg{ .name = "complex-struct-init", .cfun = cfunComplexZigStruct },
    Reg{ .name = "get-counter", .cfun = cfunGetComplexCounter },
    Reg{ .name = "alloc-init", .cfun = cfunInitZigAllocator },
    Reg.empty,
};

test "complex abstract" {
    try init();
    // Testing `gc` function implementation. The memory for our abstract type is allocated
    // with testing.allocator, so the test will fail if we leak memory. And here Janet is
    // responsible for freeing all the allocated memory on deinit.
    defer deinit();
    complex_zig_struct_abstract_type.register();
    var env = coreEnv(null);
    cfunsPrefix(env, "zig", &complex_zig_struct_cfuns);
    // Init our `testing.allocator` as a Janet abstract type.
    try doString(env, "(def ally (zig/alloc-init))", "main", null);
    // Init our complex struct which requires a Zig allocator.
    try doString(env, "(def st (zig/complex-struct-init ally))", "main", null);
    try doString(env, "(assert (= (zig/get-counter st) 0))", "main", null);
    // Testing `get` implementation.
    try doString(env, "(assert (= (get st :me) nil))", "main", null);
    // Testing `put` implementation.
    try doString(env, "(put st :me [1 2 3])", "main", null);
    // Testing `gcMark` implementation. If we don't implement gcMark, GC will collect [1 2 3]
    // tuple and Janet will panic trying to retrieve it.
    try doString(env, "(gccollect)", "main", null);
    try doString(env, "(assert (= (get st :me) [1 2 3]))", "main", null);
    // Testing `call` implementation.
    try doString(env, "(st 5)", "main", null);
    try doString(env, "(assert (= (zig/get-counter st) 5))", "main", null);
    // Testing marshaling.
    try doString(env, "(def marshaled (marshal st))", "main", null);
    try doString(env, "(def unmarshaled (unmarshal marshaled))", "main", null);
    try doString(env, "(assert (= (zig/get-counter unmarshaled) 5))", "main", null);
    // Testing `compare` implementation.
    try doString(env, "(assert (= (zig/get-counter st) 5))", "main", null);
    try doString(env, "(assert (= (zig/get-counter unmarshaled) 5))", "main", null);
    try doString(env, "(assert (compare= unmarshaled st))", "main", null);
    try doString(env, "(st 3)", "main", null);
    try doString(env, "(assert (compare> unmarshaled st))", "main", null);
    // Testing `hash` implementation.
    try doString(env, "(assert (= (hash st) 1337))", "main", null);
    // Testing `next` implementation.
    try doString(env, "(put st :mimi 42)", "main", null);
    try doString(
        env,
        \\(eachp [k v] st
        \\  (assert (or (and (= k :me)   (= v [1 2 3]))
        \\              (and (= k :mimi) (= v 42)))))
    ,
        "main",
        null,
    );
}
