const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

// Configuration

// TODO: pass this option from the build system.
pub const JANET_NO_NANBOX = false;

// pub const c = @cImport({
//     if (JANET_NO_NANBOX) {
//         @cDefine("JANET_NO_NANBOX", {});
//     }
//     @cInclude("janet.h");
// });
const c = @import("cjanet");

// Bindings

pub const Signal = enum(c_int) {
    ok,
    @"error",
    debug,
    yield,
    user0,
    user1,
    user2,
    user3,
    user4,
    user5,
    user6,
    user7,
    user8,
    user9,

    pub const Error = error{
        @"error",
        debug,
        yield,
        user0,
        user1,
        user2,
        user3,
        user4,
        user5,
        user6,
        user7,
        user8,
        user9,
    };

    pub fn toError(signal: Signal) Error {
        return switch (signal) {
            Signal.ok => unreachable,
            Signal.@"error" => Error.@"error",
            Signal.debug => Error.debug,
            Signal.yield => Error.yield,
            Signal.user0 => Error.user0,
            Signal.user1 => Error.user1,
            Signal.user2 => Error.user2,
            Signal.user3 => Error.user3,
            Signal.user4 => Error.user4,
            Signal.user5 => Error.user5,
            Signal.user6 => Error.user6,
            Signal.user7 => Error.user7,
            Signal.user8 => Error.user8,
            Signal.user9 => Error.user9,
        };
    }
};

pub fn init() !void {
    if (c.janet_init() != 0) return error.InitError;
}
pub fn deinit() void {
    c.janet_deinit();
}
pub fn mcall(name: [:0]const u8, argv: []Janet) Signal.Error!void {
    const signal = @as(
        *const Signal,
        @ptrCast(&c.janet_mcall(name.ptr, @as(i32, @intCast(argv.len)), @as([*c]c.Janet, @ptrCast(argv.ptr)))),
    ).*;
    switch (signal) {
        .ok => {},
        else => return signal.toError(),
    }
}

pub const TryState = extern struct {
    stackn: i32,
    gc_handle: c_int,
    vm_fiber: *Fiber,
    vm_jmp_buf: *c.jmp_buf,
    vm_return_reg: *Janet,
    buf: c.jmp_buf,
    payload: Janet,

    pub fn toC(self: *TryState) *c.JanetTryState {
        return @as(*c.JanetTryState, @ptrCast(self));
    }
    pub fn tryInit(state: *TryState) void {
        c.janet_try_init(state.toC());
    }
    pub fn @"try"(state: *TryState) Signal.Error!void {
        tryInit(state);
        const signal = blk: {
            if (builtin.target.os.tag.isDarwin() or
                builtin.target.os.tag == .freebsd or
                builtin.target.os.tag == .openbsd or
                builtin.target.os.tag == .netbsd or
                builtin.target.os.tag == .dragonfly)
            {
                break :blk @as(*Signal, @ptrCast(&c._setjmp(&state.buf))).*;
            } else {
                break :blk @as(*Signal, @ptrCast(&c.setjmp(&state.buf))).*;
            }
        };
        switch (signal) {
            .ok => {},
            else => return signal.toError(),
        }
    }
    pub fn restore(state: *TryState) void {
        c.janet_restore(state.toC());
    }
};

pub fn panic(message: [:0]const u8) noreturn {
    c.janet_panic(message.ptr);
}
pub fn print(message: [:0]const u8) void {
    c.janet_dynprintf("out", std.io.getStdOut().handle, message.ptr);
}
pub fn eprint(message: [:0]const u8) void {
    c.janet_dynprintf("err", std.io.getStdErr().handle, message.ptr);
}

pub fn arity(ary: i32, min: i32, max: i32) void {
    c.janet_arity(ary, min, max);
}
pub fn fixArity(ary: i32, fix: i32) void {
    c.janet_fixarity(ary, fix);
}

pub fn getMethod(method: Keyword, methods: [*]const Method, out: *Janet) bool {
    return c.janet_getmethod(
        method.toC(),
        @as([*c]const c.JanetMethod, @ptrCast(methods)),
        @as(*c.Janet, @ptrCast(out)),
    ) > 0;
}
// Returns Janet.nil if there's no next method.
pub fn nextMethod(methods: [*]const Method, key: Janet) Janet {
    return Janet.fromC(c.janet_nextmethod(@as([*c]const c.JanetMethod, @ptrCast(methods)), key.toC()));
}

pub fn nil() Janet {
    return Janet.fromC(c.janet_wrap_nil());
}
pub fn keyword(str: []const u8) Janet {
    return Janet.fromC(c.janet_keywordv(str.ptr, @as(i32, @intCast(str.len))));
}
pub fn symbol(str: []const u8) Janet {
    return Janet.fromC(c.janet_symbolv(str.ptr, @as(i32, @intCast(str.len))));
}
pub fn string(str: []const u8) Janet {
    return Janet.fromC(c.janet_stringv(str.ptr, @as(i32, @intCast(str.len))));
}
pub fn numberSafe(x: f64) Janet {
    return Janet.fromC(c.janet_wrap_number_safe(x));
}
pub fn wrap(comptime T: type, value: T) Janet {
    return switch (T) {
        f64 => Janet.fromC(c.janet_wrap_number(value)),
        u32 => Janet.fromC(c.janet_wrap_number(@as(f64, @floatFromInt(value)))),
        i32 => Janet.fromC(c.janet_wrap_number(@as(f64, @floatFromInt(value)))),
        i64 => Janet.fromC(c.janet_wrap_number(@as(f64, @floatFromInt(value)))),
        usize => Janet.fromC(c.janet_wrap_number(@as(f64, @floatFromInt(value)))),
        bool => if (value) Janet.fromC(c.janet_wrap_true()) else Janet.fromC(c.janet_wrap_false()),
        String => value.wrap(),
        Symbol => value.wrap(),
        Keyword => value.wrap(),
        *Array => value.wrap(),
        Tuple => value.wrap(),
        Struct => value.wrap(),
        *Fiber => value.wrap(),
        *Buffer => value.wrap(),
        *Function => value.wrap(),
        CFunction => value.wrap(),
        *Table => value.wrap(),
        *anyopaque => Janet.fromC(c.janet_wrap_pointer(value)),
        []const u8 => string(value),
        else => @compileError("Wrapping is not supported for '" ++ @typeName(T) ++ "'"),
    };
}

pub fn get(comptime T: type, argv: [*]const Janet, n: i32) T {
    return switch (T) {
        f64 => c.janet_getnumber(Janet.toConstPtr(argv), n),
        u32 => @as(u32, @intCast(c.janet_getnat(Janet.toConstPtr(argv), n))),
        i32 => c.janet_getinteger(Janet.toConstPtr(argv), n),
        i64 => c.janet_getinteger64(Janet.toConstPtr(argv), n),
        u64 => c.janet_getuinteger64(Janet.toConstPtr(argv), n),
        usize => c.janet_getsize(Janet.toConstPtr(argv), n),
        bool => c.janet_getboolean(Janet.toConstPtr(argv), n) > 0,
        *Array => Array.fromC(c.janet_getarray(Janet.toConstPtr(argv), n)),
        Tuple => Tuple.fromC(c.janet_gettuple(Janet.toConstPtr(argv), n)),
        *Table => Table.fromC(c.janet_gettable(Janet.toConstPtr(argv), n)),
        Struct => Struct.fromC(c.janet_getstruct(Janet.toConstPtr(argv), n)),
        String => String.fromC(c.janet_getstring(Janet.toConstPtr(argv), n)),
        Symbol => Symbol.fromC(c.janet_getsymbol(Janet.toConstPtr(argv), n)),
        Keyword => Keyword.fromC(c.janet_getkeyword(Janet.toConstPtr(argv), n)),
        *Buffer => Buffer.fromC(c.janet_getbuffer(Janet.toConstPtr(argv), n)),
        *anyopaque => c.janet_getpointer(Janet.toConstPtr(argv), n) orelse unreachable,
        CFunction => CFunction.fromC(c.janet_getcfunction(Janet.toConstPtr(argv), n)),
        *Fiber => Fiber.fromC(c.janet_getfiber(Janet.toConstPtr(argv), n) orelse unreachable),
        *Function => Function.fromC(
            c.janet_getfunction(Janet.toConstPtr(argv), n) orelse unreachable,
        ),
        View => @as(*View, @ptrCast(&c.janet_getindexed(Janet.toConstPtr(argv), n))).*,
        ByteView => @as(*ByteView, @ptrCast(&c.janet_getbytes(Janet.toConstPtr(argv), n))).*,
        DictView => @as(*DictView, @ptrCast(&c.janet_getdictionary(Janet.toConstPtr(argv), n))).*,
        Range => @as(*Range, @ptrCast(&c.janet_getslice(n, Janet.toConstPtr(argv)))).*,
        AbstractType => @compileError("Please use 'getAbstract' instead"),
        else => @compileError("Get is not supported for '" ++ @typeName(T) ++ "'"),
    };
}

pub fn getAbstract(
    argv: [*]const Janet,
    n: i32,
    comptime ValueType: type,
    at: *const Abstract(ValueType).Type,
) Abstract(ValueType) {
    return Abstract(ValueType).fromC(
        c.janet_getabstract(Janet.toConstPtr(argv), n, at.toC()) orelse unreachable,
    );
}
pub fn getHalfRange(argv: [*]const Janet, n: i32, length: i32, which: [:0]const u8) i32 {
    return c.janet_gethalfrange(Janet.toConstPtr(argv), n, length, which.ptr);
}
pub fn getArgIndex(argv: [*]const Janet, n: i32, length: i32, which: [:0]const u8) i32 {
    return c.janet_getargindex(Janet.toConstPtr(argv), n, length, which.ptr);
}
pub fn getFlags(argv: [*]const Janet, n: i32, flags: [:0]const u8) u64 {
    return c.janet_getflags(Janet.toConstPtr(argv), n, flags.ptr);
}

pub fn opt(comptime T: type, argv: [*]const Janet, argc: i32, n: i32, dflt: T) T {
    return switch (T) {
        f64 => c.janet_optnumber(Janet.toConstPtr(argv), argc, n, dflt),
        u32 => @as(u32, @intCast(c.janet_optnat(Janet.toConstPtr(argv), argc, n, @as(i32, @intCast(dflt))))),
        i32 => c.janet_optinteger(Janet.toConstPtr(argv), argc, n, dflt),
        i64 => c.janet_optinteger64(Janet.toConstPtr(argv), argc, n, dflt),
        usize => c.janet_optsize(Janet.toConstPtr(argv), argc, n, dflt),
        Tuple => Tuple.fromC(c.janet_opttuple(Janet.toConstPtr(argv), argc, n, dflt.toC())),
        Struct => Struct.fromC(c.janet_optstruct(Janet.toConstPtr(argv), argc, n, dflt.toC())),
        String => String.fromC(c.janet_optstring(Janet.toConstPtr(argv), argc, n, dflt.toC())),
        Symbol => Symbol.fromC(c.janet_optsymbol(Janet.toConstPtr(argv), argc, n, dflt.toC())),
        Keyword => Keyword.fromC(c.janet_optkeyword(Janet.toConstPtr(argv), argc, n, dflt.toC())),
        bool => c.janet_optboolean(Janet.toConstPtr(argv), argc, n, if (dflt) 1 else 0) > 0,
        *anyopaque => c.janet_optpointer(Janet.toConstPtr(argv), argc, n, dflt) orelse unreachable,
        CFunction => CFunction.fromC(
            c.janet_optcfunction(Janet.toConstPtr(argv), argc, n, dflt.toC()),
        ),
        *Fiber => Fiber.fromC(
            c.janet_optfiber(Janet.toConstPtr(argv), argc, n, dflt.toC()) orelse unreachable,
        ),
        *Function => Function.fromC(
            c.janet_optfunction(Janet.toConstPtr(argv), argc, n, dflt.toC()) orelse unreachable,
        ),
        AbstractType => @compileError("Please use 'optAbstract' instead"),
        *Array => @compileError("Please use 'optArray' instead"),
        *Table => @compileError("Please use 'optTable' instead"),
        *Buffer => @compileError("Please use 'optBuffer' instead"),
        else => @compileError("Opt is not supported for '" ++ @typeName(T) ++ "'"),
    };
}

pub fn optAbstract(
    argv: [*]const Janet,
    argc: i32,
    n: i32,
    comptime ValueType: type,
    at: *const Abstract(ValueType).Type,
    dflt: Abstract(ValueType),
) Abstract(ValueType) {
    return c.janet_optabstract(
        Janet.toConstPtr(argv),
        argc,
        n,
        at.toC(),
        dflt.toC(),
    ) orelse unreachable;
}
pub fn optArray(argv: [*]const Janet, argc: i32, n: i32, dflt_len: i32) *Array {
    return Array.fromC(c.janet_optarray(Janet.toConstPtr(argv), argc, n, dflt_len));
}
pub fn optTable(argv: [*]const Janet, argc: i32, n: i32, dflt_len: i32) *Table {
    return Table.fromC(c.janet_opttable(Janet.toConstPtr(argv), argc, n, dflt_len));
}
pub fn optBuffer(argv: [*]const Janet, argc: i32, n: i32, dflt_len: i32) *Buffer {
    return Buffer.fromC(c.janet_optbuffer(Janet.toConstPtr(argv), argc, n, dflt_len));
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

// Waiting for "Allocgate", new model of allocators for Zig. After that we can wrap these
// into idiomatic Zig allocators.
pub fn malloc(size: usize) ?*anyopaque {
    return c.janet_malloc(size);
}
pub fn realloc(ptr: *anyopaque, size: usize) ?*anyopaque {
    return c.janet_realloc(ptr, size);
}
pub fn calloc(nmemb: usize, size: usize) ?*anyopaque {
    return c.janet_calloc(nmemb, size);
}
pub fn free(ptr: *anyopaque) void {
    c.janet_free(ptr);
}
pub const ScratchFinalizer = *const fn (ptr: *anyopaque) callconv(.C) void;
pub const ScratchFinalizerC = *const fn (ptr: ?*anyopaque) callconv(.C) void;
pub fn smalloc(size: usize) ?*anyopaque {
    return c.janet_smalloc(size);
}
pub fn srealloc(ptr: *anyopaque, size: usize) ?*anyopaque {
    return c.janet_srealloc(ptr, size);
}
pub fn scalloc(nmemb: usize, size: usize) ?*anyopaque {
    return c.janet_scalloc(nmemb, size);
}
pub fn sfinalizer(ptr: *anyopaque, finalizer: ScratchFinalizer) void {
    return c.janet_sfinalizer(ptr, @as(ScratchFinalizerC, @ptrCast(finalizer)));
}
pub fn sfree(ptr: *anyopaque) void {
    c.janet_sfree(ptr);
}

pub fn sortedKeys(dict: [*]const KV, cap: i32, index_buffer: *i32) i32 {
    return c.janet_sorted_keys(@as([*c]const c.JanetKV, @ptrCast(dict)), cap, index_buffer);
}
pub fn dictionaryGet(data: [*]const KV, cap: i32, key: Janet) ?Janet {
    const value = Janet.fromC(
        c.janet_dictionary_get(@as([*c]const c.JanetKV, @ptrCast(data)), cap, key.toC()),
    );
    if (value.checkType(.nil)) {
        return null;
    } else {
        return value;
    }
}
pub fn dictionaryNext(kvs: [*]const KV, cap: i32, kv: *const KV) ?*const KV {
    return @as(?*const KV, @ptrCast(c.janet_dictionary_next(
        @as([*c]const c.JanetKV, @ptrCast(kvs)),
        cap,
        @as([*c]const c.JanetKV, @ptrCast(kv)),
    )));
}

pub const BuildConfig = extern struct {
    major: c_uint,
    minor: c_uint,
    patch: c_uint,
    bits: c_uint,
};
pub fn configCurrent() BuildConfig {
    return BuildConfig{
        .major = c.JANET_VERSION_MAJOR,
        .minor = c.JANET_VERSION_MINOR,
        .patch = c.JANET_VERSION_PATCH,
        .bits = c.JANET_CURRENT_CONFIG_BITS,
    };
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

pub const TFLAG_NIL = (1 << @intFromEnum(Janet.Type.nil));
pub const TFLAG_BOOLEAN = (1 << @intFromEnum(Janet.Type.boolean));
pub const TFLAG_FIBER = (1 << @intFromEnum(Janet.Type.fiber));
pub const TFLAG_NUMBER = (1 << @intFromEnum(Janet.Type.number));
pub const TFLAG_STRING = (1 << @intFromEnum(Janet.Type.string));
pub const TFLAG_SYMBOL = (1 << @intFromEnum(Janet.Type.symbol));
pub const TFLAG_KEYWORD = (1 << @intFromEnum(Janet.Type.keyword));
pub const TFLAG_ARRAY = (1 << @intFromEnum(Janet.Type.array));
pub const TFLAG_TUPLE = (1 << @intFromEnum(Janet.Type.tuple));
pub const TFLAG_TABLE = (1 << @intFromEnum(Janet.Type.table));
pub const TFLAG_STRUCT = (1 << @intFromEnum(Janet.Type.@"struct"));
pub const TFLAG_BUFFER = (1 << @intFromEnum(Janet.Type.buffer));
pub const TFLAG_FUNCTION = (1 << @intFromEnum(Janet.Type.function));
pub const TFLAG_CFUNCTION = (1 << @intFromEnum(Janet.Type.cfunction));
pub const TFLAG_ABSTRACT = (1 << @intFromEnum(Janet.Type.abstract));
pub const TFLAG_POINTER = (1 << @intFromEnum(Janet.Type.pointer));

// Some abstractions
pub const TFLAG_BYTES = TFLAG_STRING | TFLAG_SYMBOL | TFLAG_BUFFER | TFLAG_KEYWORD;
pub const TFLAG_INDEXED = TFLAG_ARRAY | TFLAG_TUPLE;
pub const TFLAG_DICTIONARY = TFLAG_TABLE | TFLAG_STRUCT;
pub const TFLAG_LENGTHABLE = TFLAG_BYTES | TFLAG_INDEXED | TFLAG_DICTIONARY;
pub const TFLAG_CALLABLE = TFLAG_FUNCTION | TFLAG_CFUNCTION | TFLAG_LENGTHABLE | TFLAG_ABSTRACT;

pub const Janet = blk: {
    if (JANET_NO_NANBOX or
        builtin.target.cpu.arch.isARM() or
        builtin.target.cpu.arch == .aarch64)
    {
        break :blk extern struct {
            as: extern union {
                u64: u64,
                number: f64,
                integer: i32,
                pointer: *anyopaque,
                cpointer: *const anyopaque,
            },
            type: Type,

            pub const Type = JanetType;
            pub usingnamespace JanetMixin;
        };
    } else if (builtin.target.cpu.arch == .x86_64) {
        break :blk extern union {
            u64: u64,
            i64: i64,
            number: f64,
            pointer: *anyopaque,

            pub const Type = JanetType;
            pub usingnamespace JanetMixin;
        };
    } else if (builtin.target.cpu.arch.endianess() == .Big) {
        break :blk extern union {
            tagged: extern struct {
                type: u32,
                payload: extern union {
                    integer: u32,
                    pointer: *anyopaque,
                },
            },
            number: f64,
            u64: u64,

            pub const Type = JanetType;
            pub usingnamespace JanetMixin;
        };
    } else if (builtin.target.cpu.arch.endianess() == .Little) {
        break :blk extern union {
            tagged: extern struct {
                payload: extern union {
                    integer: u32,
                    pointer: *anyopaque,
                },
                type: u32,
            },
            number: f64,
            u64: u64,

            pub const Type = JanetType;
            pub usingnamespace JanetMixin;
        };
    }
};

const JanetMixin = struct {
    pub fn fromC(janet: c.Janet) Janet {
        return @as(*const Janet, @ptrCast(&janet)).*;
    }
    pub fn toC(janet: *const Janet) c.Janet {
        return @as(*const c.Janet, @ptrCast(janet)).*;
    }
    pub fn toConstPtr(janet: [*]const Janet) [*c]const c.Janet {
        return @as([*c]const c.Janet, @ptrCast(janet));
    }

    pub fn checkType(janet: Janet, typ: Janet.Type) bool {
        return c.janet_checktype(janet.toC(), @as(*const c.JanetType, @ptrCast(&typ)).*) > 0;
    }
    pub fn checkTypes(janet: Janet, typeflags: i32) bool {
        return c.janet_checktypes(janet.toC(), typeflags) > 0;
    }
    pub fn truthy(janet: Janet) bool {
        return c.janet_truthy(janet.toC()) > 0;
    }
    pub fn janetType(janet: Janet) Janet.Type {
        return @as(*const Janet.Type, @ptrCast(&c.janet_type(janet.toC()))).*;
    }
    pub fn getAbstractType(janet: Janet) *const AbstractType {
        return AbstractType.fromC(c.janet_get_abstract_type(janet.toC()));
    }

    pub fn in(ds: Janet, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_in(ds.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn get(ds: Janet, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_get(ds.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn next(ds: Janet, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_next(ds.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn getIndex(ds: Janet, index: i32) ?Janet {
        const value = Janet.fromC(c.janet_getindex(ds.toC(), index));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn length(x: Janet) i32 {
        return c.janet_length(x.toC());
    }
    pub fn lengthv(x: Janet) Janet {
        return fromC(c.janet_lengthv(x.toC()));
    }
    pub fn put(ds: Janet, key: Janet, value: Janet) void {
        c.janet_put(ds.toC(), key.toC(), value.toC());
    }
    pub fn putIndex(ds: Janet, index: i32, value: Janet) void {
        c.janet_putindex(ds.toC(), index, value.toC());
    }

    pub fn indexedView(seq: Janet) !View {
        var data: [*]const Janet = undefined;
        var len: i32 = undefined;
        const rs = c.janet_indexed_view(seq.toC(), @as([*c][*c]const c.Janet, @ptrCast(&data)), &len);
        if (rs <= 0) return error.CannotConstructView;
        return View{ .items = data, .len = len };
    }
    pub fn bytesView(str: Janet) !ByteView {
        var data: [*]const u8 = undefined;
        var len: i32 = undefined;
        const rs = c.janet_bytes_view(str.toC(), @as([*c][*c]const u8, @ptrCast(&data)), &len);
        if (rs <= 0) return error.CannotConstructView;
        return ByteView{ .bytes = data, .len = len };
    }
    pub fn dictionaryView(tab: Janet) !DictView {
        var data: [*]const KV = undefined;
        var len: i32 = undefined;
        var cap: i32 = undefined;
        const rs = c.janet_dictionary_view(
            tab.toC(),
            @as([*c][*c]const c.JanetKV, @ptrCast(&data)),
            &len,
            &cap,
        );
        if (rs <= 0) return error.CannotConstructView;
        return DictView{ .kvs = data, .len = len, .cap = cap };
    }

    pub fn equals(x: Janet, y: Janet) bool {
        return c.janet_equals(x.toC(), y.toC()) > 0;
    }
    pub fn hash(x: Janet) i32 {
        return c.janet_hash(x.toC());
    }
    pub fn compare(x: Janet, y: Janet) c_int {
        return c.janet_compare(x.toC(), y.toC());
    }

    pub fn unwrap(janet: Janet, comptime T: type) !T {
        switch (T) {
            f64 => {
                if (!janet.checkType(.number)) return error.NotNumber;
                return c.janet_unwrap_number(janet.toC());
            },
            u32 => {
                if (!janet.checkType(.number)) return error.NotNumber;
                const value = c.janet_unwrap_integer(janet.toC());
                if (value < 0) return error.NegativeValue;
                return @as(u32, @intCast(value));
            },
            i32 => {
                if (!janet.checkType(.number)) return error.NotNumber;
                return c.janet_unwrap_integer(janet.toC());
            },
            i64 => {
                if (!janet.checkType(.number)) return error.NotNumber;
                return @as(i64, @intCast(c.janet_unwrap_integer(janet.toC())));
            },
            usize => {
                if (!janet.checkType(.number)) return error.NotNumber;
                const value = c.janet_unwrap_integer(janet.toC());
                if (value < 0) return error.NegativeValue;
                return @as(usize, @intCast(value));
            },
            bool => {
                if (!janet.checkType(.boolean)) return error.NotBoolean;
                return c.janet_unwrap_boolean(janet.toC()) > 0;
            },
            String => {
                if (!janet.checkType(.string)) return error.NotString;
                return String.fromC(c.janet_unwrap_string(janet.toC()));
            },
            Keyword => {
                if (!janet.checkType(.keyword)) return error.NotKeyword;
                return Keyword.fromC(c.janet_unwrap_keyword(janet.toC()));
            },
            Symbol => {
                if (!janet.checkType(.symbol)) return error.NotSymbol;
                return Symbol.fromC(c.janet_unwrap_symbol(janet.toC()));
            },
            Tuple => {
                if (!janet.checkType(.tuple)) return error.NotTuple;
                return Tuple.fromC(c.janet_unwrap_tuple(janet.toC()));
            },
            *Array => {
                if (!janet.checkType(.array)) return error.NotArray;
                return @as(*Array, @ptrCast(c.janet_unwrap_array(janet.toC())));
            },
            *Buffer => {
                if (!janet.checkType(.buffer)) return error.NotBuffer;
                return @as(*Buffer, @ptrCast(c.janet_unwrap_buffer(janet.toC())));
            },
            Struct => {
                if (!janet.checkType(.@"struct")) return error.NotStruct;
                return Struct.fromC(c.janet_unwrap_struct(janet.toC()));
            },
            *Table => {
                if (!janet.checkType(.table)) return error.NotTable;
                return @as(*Table, @ptrCast(c.janet_unwrap_table(janet.toC())));
            },
            *anyopaque => {
                if (!janet.checkType(.pointer)) return error.NotPointer;
                return c.janet_unwrap_pointer(janet.toC()) orelse unreachable;
            },
            CFunction => {
                if (!janet.checkType(.cfunction)) return error.NotCFunction;
                return CFunction.fromC(c.janet_unwrap_cfunction(janet.toC()));
            },
            *Function => {
                if (!janet.checkType(.function)) return error.NotFunction;
                return Function.fromC(c.janet_unwrap_function(janet.toC()) orelse unreachable);
            },
            *Fiber => {
                if (!janet.checkType(.fiber)) return error.NotFiber;
                return Fiber.fromC(c.janet_unwrap_fiber(janet.toC()) orelse unreachable);
            },
            AbstractType => @compileError("Please use 'unwrapAbstract' instead"),
            else => @compileError("Unwrapping is not supported for '" ++ @typeName(T) ++ "'"),
        }
        unreachable;
    }
    pub fn unwrapAbstract(janet: Janet, comptime ValueType: type) !Abstract(ValueType) {
        if (!janet.checkType(.abstract)) return error.NotAbstract;
        return Abstract(ValueType).fromC(c.janet_unwrap_abstract(janet.toC()) orelse unreachable);
    }
};

pub const KV = extern struct {
    key: Janet,
    value: Janet,

    pub fn toC(self: *KV) [*c]c.JanetKV {
        return @as([*c]c.JanetKV, @ptrCast(self));
    }
};

pub const String = struct {
    slice: TypeImpl,

    pub const TypeImpl = []const u8;
    pub const TypeC = [*]const u8;
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
        const len: usize = @intCast(c.janet_string_head(ptr).*.length);
        return String{ .slice = ptr[0..len] };
    }

    pub fn init(buf: []u8) String {
        return fromC(c.janet_string(buf.ptr, @as(i32, @intCast(buf.len))));
    }

    pub fn head(self: String) *Head {
        const h = c.janet_string_head(self.slice.ptr);
        return @as(*Head, @ptrCast(@alignCast(h)));
    }
    pub fn length(self: String) i32 {
        return self.head().length;
    }

    pub fn begin(len: i32) [*]u8 {
        return @as([*]u8, @ptrCast(c.janet_string_begin(len) orelse unreachable));
    }
    pub fn end(str: [*]u8) String {
        return fromC(c.janet_string_end(str));
    }
    pub fn compare(lhs: String, rhs: String) c_int {
        return c.janet_string_compare(lhs.toC(), rhs.toC());
    }
    pub fn equal(lhs: String, rhs: String) bool {
        return c.janet_string_equal(lhs.toC(), rhs.toC()) > 0;
    }
    pub fn equalConst(lhs: String, rhs: []u8, rhash: i32) bool {
        return c.janet_string_equalconst(lhs.toC(), rhs.ptr, @as(i32, @intCast(rhs.len)), rhash) > 0;
    }

    pub fn wrap(self: String) Janet {
        return Janet.fromC(c.janet_wrap_string(self.toC()));
    }
};

pub const Symbol = struct {
    slice: TypeImpl,

    pub const TypeImpl = []const u8;
    pub const TypeC = [*]const u8;

    pub fn toC(self: Symbol) TypeC {
        return self.slice.ptr;
    }
    pub fn fromC(ptr: TypeC) Symbol {
        const len: usize = @intCast(c.janet_string_head(ptr).*.length);
        return Symbol{ .slice = ptr[0..len] };
    }

    pub fn init(str: []const u8) Symbol {
        return fromC(c.janet_symbol(str.ptr, @as(i32, @intCast(str.len))));
    }

    pub fn wrap(self: Symbol) Janet {
        return Janet.fromC(c.janet_wrap_symbol(self.toC()));
    }

    pub fn gen() Symbol {
        return fromC(c.janet_symbol_gen());
    }
};

pub const Keyword = struct {
    slice: TypeImpl,

    pub const TypeImpl = []const u8;
    pub const TypeC = [*]const u8;

    pub fn toC(self: Keyword) TypeC {
        return self.slice.ptr;
    }
    pub fn fromC(ptr: TypeC) Keyword {
        const len: usize = @intCast(c.janet_string_head(ptr).*.length);
        return Keyword{ .slice = ptr[0..len] };
    }

    pub fn init(str: []const u8) Keyword {
        return fromC(c.janet_keyword(str.ptr, @as(i32, @intCast(str.len))));
    }

    pub fn wrap(self: Keyword) Janet {
        return Janet.fromC(c.janet_wrap_keyword(self.toC()));
    }
};

pub const Array = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    data: [*]Janet,

    pub fn toC(self: *Array) *c.JanetArray {
        return @as(*c.JanetArray, @ptrCast(self));
    }
    pub fn fromC(ptr: *c.JanetArray) *Array {
        return @as(*Array, @ptrCast(ptr));
    }

    pub fn init(capacity: i32) *Array {
        return fromC(c.janet_array(capacity));
    }
    pub fn initN(elements: []const Janet) *Array {
        return fromC(c.janet_array_n(
            @as([*c]const c.Janet, @ptrCast(elements.ptr)),
            @as(i32, @intCast(elements.len)),
        ));
    }
    pub fn ensure(self: *Array, capacity: i32, growth: i32) void {
        c.janet_array_ensure(self.toC(), capacity, growth);
    }
    pub fn setCount(self: *Array, count: i32) void {
        c.janet_array_setcount(self.toC(), count);
    }
    pub fn push(self: *Array, x: Janet) void {
        c.janet_array_push(self.toC(), x.toC());
    }
    pub fn pop(self: *Array) Janet {
        return Janet.fromC(c.janet_array_pop(self.toC()));
    }
    pub fn peek(self: *Array) Janet {
        return Janet.fromC(c.janet_array_peek(self.toC()));
    }

    pub fn wrap(self: *Array) Janet {
        return Janet.fromC(c.janet_wrap_array(self.toC()));
    }
};

pub const Buffer = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    data: [*]u8,

    pub fn toC(self: *Buffer) *c.JanetBuffer {
        return @as(*c.JanetBuffer, @ptrCast(self));
    }
    pub fn fromC(ptr: *c.JanetBuffer) *Buffer {
        return @as(*Buffer, @ptrCast(ptr));
    }

    /// C function: janet_buffer_init
    pub fn init(buf: *Buffer, capacity: i32) *Buffer {
        return fromC(c.janet_buffer_init(buf.toC(), capacity));
    }
    /// C function: janet_buffer
    pub fn initDynamic(capacity: i32) *Buffer {
        return fromC(c.janet_buffer(capacity));
    }
    pub fn initN(bytes: []const u8) *Buffer {
        var buf = initDynamic(@as(i32, @intCast(bytes.len)));
        buf.pushBytes(bytes);
        return buf;
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
        c.janet_buffer_push_bytes(self.toC(), bytes.ptr, @as(i32, @intCast(bytes.len)));
    }
    pub fn pushString(self: *Buffer, str: String) void {
        c.janet_buffer_push_string(self.toC(), str.toC());
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

    pub fn wrap(self: *Buffer) Janet {
        return Janet.fromC(c.janet_wrap_buffer(self.toC()));
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
        const p = @as([*]const Janet, @ptrCast(ptr));
        const janet_head = c.janet_tuple_head(ptr);
        const h = @as(*Head, @ptrCast(@alignCast(janet_head)));
        const len = @as(usize, @intCast(h.length));
        return Tuple{ .slice = p[0..len] };
    }
    pub fn toC(self: Tuple) TypeC {
        return @as(TypeC, @ptrCast(self.slice.ptr));
    }

    pub fn head(self: Tuple) *Head {
        const h = c.janet_tuple_head(@as(*const c.Janet, @ptrCast(self.slice.ptr)));
        return @as(*Head, @ptrCast(@alignCast(h)));
    }
    pub fn length(self: Tuple) i32 {
        return self.head().length;
    }

    pub fn begin(len: i32) [*]Janet {
        return @as([*]Janet, @ptrCast(c.janet_tuple_begin(len)));
    }
    pub fn end(tuple: [*]Janet) Tuple {
        return fromC(c.janet_tuple_end(@as([*c]c.Janet, @ptrCast(tuple))));
    }
    pub fn initN(values: []const Janet) Tuple {
        return fromC(c.janet_tuple_n(
            @as([*c]const c.Janet, @ptrCast(values.ptr)),
            @as(i32, @intCast(values.len)),
        ));
    }

    pub fn wrap(self: Tuple) Janet {
        return Janet.fromC(c.janet_wrap_tuple(self.toC()));
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
        proto: ?[*]const KV,
        data: [*]const KV,
    };

    pub fn toC(self: Struct) TypeC {
        return @as([*]const c.JanetKV, @ptrCast(self.ptr));
    }
    pub fn fromC(ptr: TypeC) Struct {
        return Struct{ .ptr = @as(TypeImpl, @ptrCast(ptr)) };
    }

    pub fn initN(kvs: []const KV) Struct {
        var st = begin(@as(i32, @intCast(kvs.len)));
        for (kvs) |kv| put(st, kv.key, kv.value);
        return end(st);
    }

    pub fn head(self: Struct) *Head {
        const h = c.janet_struct_head(@as(*const c.JanetKV, @ptrCast(self.toC())));
        return @as(*Head, @ptrCast(@alignCast(h)));
    }
    pub fn length(self: Struct) i32 {
        return self.head().length;
    }

    pub fn begin(count: i32) [*]KV {
        return @as([*]KV, @ptrCast(c.janet_struct_begin(count)));
    }
    pub fn put(st: [*]KV, key: Janet, value: Janet) void {
        c.janet_struct_put(@as([*c]c.JanetKV, @ptrCast(st)), key.toC(), value.toC());
    }
    pub fn end(st: [*]KV) Struct {
        return fromC(c.janet_struct_end(@as([*c]c.JanetKV, @ptrCast(st))));
    }
    pub fn get(self: Struct, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_struct_get(self.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn getEx(self: Struct, key: Janet, which: *Struct) ?Janet {
        const value = Janet.fromC(c.janet_struct_get_ex(
            self.toC(),
            key.toC(),
            @as([*c]c.JanetStruct, @ptrCast(&which.ptr)),
        ));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn rawGet(self: Struct, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_struct_rawget(self.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn toTable(self: Struct) *Table {
        return Table.fromC(c.janet_struct_to_table(self.toC()));
    }
    pub fn find(self: Struct, key: Janet) ?*const KV {
        return @as(?*const KV, @ptrCast(c.janet_struct_find(self.toC(), key.toC())));
    }

    pub fn wrap(self: *Struct) Janet {
        return Janet.fromC(c.janet_wrap_struct(self.toC()));
    }
};

pub const Table = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    deleted: i32,
    data: *KV,
    proto: ?*Table,

    pub fn toC(table: *Table) *c.JanetTable {
        return @as(*c.JanetTable, @ptrCast(table));
    }
    pub fn fromC(janet_table: *c.JanetTable) *Table {
        return @as(*Table, @ptrCast(janet_table));
    }

    /// C function: janet_table_init
    pub fn init(table: *Table, capacity: i32) *Table {
        return fromC(c.janet_table_init(table.toC(), capacity));
    }
    /// C function: janet_table
    pub fn initDynamic(capacity: i32) *Table {
        return fromC(c.janet_table(capacity));
    }
    pub fn initRaw(table: *Table, capacity: i32) *Table {
        return fromC(c.janet_table_init_raw(table.toC(), capacity));
    }
    pub fn initN(kvs: []const KV) *Table {
        var table = initDynamic(@as(i32, @intCast(kvs.len)));
        for (kvs) |kv| table.put(kv.key, kv.value);
        return table;
    }
    pub fn deinit(self: *Table) void {
        self.deinit();
    }
    pub fn get(self: *Table, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_table_get(self.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn getEx(self: *Table, key: Janet, which: **Table) ?Janet {
        const value = Janet.fromC(c.janet_table_get_ex(
            self.toC(),
            key.toC(),
            @as([*c][*c]c.JanetTable, @ptrCast(which)),
        ));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn rawGet(self: *Table, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_table_rawget(self.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn remove(self: *Table, key: Janet) ?Janet {
        const value = Janet.fromC(c.janet_table_remove(self.toC(), key.toC()));
        if (value.checkType(.nil)) {
            return null;
        } else {
            return value;
        }
    }
    pub fn put(self: *Table, key: Janet, value: Janet) void {
        c.janet_table_put(self.toC(), key.toC(), value.toC());
    }
    pub fn toStruct(self: *Table) Struct {
        return Struct.fromC(c.janet_table_to_struct(self.toC()));
    }
    pub fn mergeTable(self: *Table, other: *Table) void {
        c.janet_table_merge_table(self.toC(), other.toC());
    }
    pub fn mergeStruct(self: *Table, other: Struct) void {
        c.janet_table_merge_struct(self.toC(), other.toC());
    }
    pub fn find(self: *Table, key: Janet) ?*const KV {
        return @as(?*const KV, @ptrCast(c.janet_table_find(self.toC(), key.toC())));
    }
    pub fn clone(self: *Table) *Table {
        return fromC(c.janet_table_clone(self.toC()));
    }
    pub fn clear(self: *Table) void {
        c.janet_table_clear(self.toC());
    }

    pub fn wrap(self: *Table) Janet {
        return Janet.fromC(c.janet_wrap_table(self.toC()));
    }
    pub fn fromEnvironment(env: *Environment) *Table {
        return @as(*Table, @ptrCast(env));
    }
    pub fn toEnvironment(table: *Table) *Environment {
        return @as(*Environment, @ptrCast(table));
    }
};

/// Inner structure is identical to `Table`. But this is a different concept from Table, the
/// data structure. It allows to run code, define values and other things. Can be converted
/// to or from Table.
pub const Environment = extern struct {
    gc: GCObject,
    count: i32,
    capacity: i32,
    deleted: i32,
    data: *KV,
    proto: ?*Environment,

    pub fn toC(table: *Environment) *c.JanetTable {
        return @as(*c.JanetTable, @ptrCast(table));
    }
    pub fn fromC(janet_table: *c.JanetTable) *Environment {
        return @as(*Environment, @ptrCast(janet_table));
    }
    pub fn toTable(env: *Environment) *Table {
        return @as(*Table, @ptrCast(env));
    }
    pub fn fromTable(table: *Table) *Environment {
        return @as(*Environment, @ptrCast(table));
    }

    pub fn init(replacements: ?*Environment) *Environment {
        return coreEnv(replacements);
    }
    pub fn coreEnv(replacements: ?*Environment) *Environment {
        return Environment.fromC(c.janet_core_env(@as([*c]c.JanetTable, @ptrCast(replacements))));
    }
    pub fn coreLookupTable(replacements: ?*Environment) *Environment {
        return Environment.fromC(
            c.janet_core_lookup_table(@as([*c]c.JanetTable, @ptrCast(replacements))),
        );
    }
    pub fn def(
        env: *Environment,
        name: [:0]const u8,
        val: Janet,
        documentation: ?[:0]const u8,
    ) void {
        if (documentation) |docs| {
            c.janet_def(env.toC(), name.ptr, val.toC(), docs.ptr);
        } else {
            c.janet_def(env.toC(), name.ptr, val.toC(), null);
        }
    }
    pub fn @"var"(
        env: *Environment,
        name: [:0]const u8,
        val: Janet,
        documentation: ?[:0]const u8,
    ) void {
        if (documentation) |docs| {
            c.janet_var(env.toC(), name.ptr, val.toC(), docs.ptr);
        } else {
            c.janet_var(env.toC(), name.ptr, val.toC(), null);
        }
    }
    pub fn cfuns(env: *Environment, reg_prefix: [:0]const u8, funs: [*]const Reg) void {
        return c.janet_cfuns(env.toC(), reg_prefix.ptr, @as([*c]const c.JanetReg, @ptrCast(funs)));
    }
    pub fn cfunsExt(env: *Environment, reg_prefix: [:0]const u8, funs: [*]const RegExt) void {
        return c.janet_cfuns_ext(
            env.toC(),
            reg_prefix.ptr,
            @as([*c]const c.JanetRegExt, @ptrCast(funs)),
        );
    }
    pub fn cfunsPrefix(env: *Environment, reg_prefix: [:0]const u8, funs: [*]const Reg) void {
        return c.janet_cfuns_prefix(
            env.toC(),
            reg_prefix.ptr,
            @as([*c]const c.JanetReg, @ptrCast(funs)),
        );
    }
    pub fn cfunsExtPrefix(env: *Environment, reg_prefix: [:0]const u8, funs: [*]const RegExt) void {
        return c.janet_cfuns_ext_prefix(
            env.toC(),
            reg_prefix.ptr,
            @as([*c]const c.JanetRegExt, @ptrCast(funs)),
        );
    }
    pub fn doString(env: *Environment, str: []const u8, source_path: [:0]const u8) !Janet {
        return try doBytes(env, str, source_path);
    }
    pub fn doBytes(env: *Environment, bytes: []const u8, source_path: [:0]const u8) !Janet {
        var janet: Janet = undefined;
        const errflags = c.janet_dobytes(
            env.toC(),
            bytes.ptr,
            @as(i32, @intCast(bytes.len)),
            source_path.ptr,
            @as(*c.Janet, @ptrCast(&janet)),
        );
        if (errflags == 0) {
            return janet;
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
    pub fn envLookup(env: *Environment) *Environment {
        return Environment.fromC(c.janet_env_lookup(env.toC()));
    }
    pub fn envLookupInto(
        renv: *Environment,
        env: *Environment,
        prefix: [:0]const u8,
        recurse: c_int,
    ) void {
        c.janet_env_lookup_into(renv.toC(), env.toC(), prefix.ptr, recurse);
    }
};

pub const GCObject = extern struct {
    flags: i32,
    data: extern union {
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
        return @as(*c.JanetFunction, @ptrCast(self));
    }
    pub fn fromC(ptr: *c.JanetFunction) *Function {
        return @as(*Function, @ptrCast(@alignCast(ptr)));
    }

    pub fn wrap(self: *Function) Janet {
        return Janet.fromC(c.janet_wrap_function(self.toC()));
    }

    pub fn pcall(
        fun: *Function,
        argv: []const Janet,
        out: *Janet,
        fiber: ?**Fiber,
    ) Signal.Error!void {
        const signal = @as(*const Signal, @ptrCast(&c.janet_pcall(
            fun.toC(),
            @as(i32, @intCast(argv.len)),
            Janet.toConstPtr(argv.ptr),
            @as(*c.Janet, @ptrCast(out)),
            @as([*c][*c]c.JanetFiber, @ptrCast(fiber)),
        ))).*;
        switch (signal) {
            .ok => {},
            else => return signal.toError(),
        }
    }
    pub fn call(fun: *Function, argv: []const Janet) Janet {
        return Janet.fromC(c.janet_call(fun.toC(), @as(i32, @intCast(argv.len)), Janet.toConstPtr(argv.ptr)));
    }
};

pub const CFunction = struct {
    ptr: TypeImpl,

    pub const TypeImpl = *const fn (argc: i32, argv: [*]Janet) callconv(.C) Janet;
    pub const TypeC = *const fn (argc: i32, argv: [*c]c.Janet) callconv(.C) c.Janet;

    pub fn toC(self: CFunction) c.JanetCFunction {
        return @as(c.JanetCFunction, @ptrCast(self.ptr));
    }
    pub fn fromC(ptr: c.JanetCFunction) CFunction {
        return CFunction{ .ptr = @as(TypeImpl, @ptrCast(@alignCast(ptr))) };
    }

    pub fn wrap(self: CFunction) Janet {
        return Janet.fromC(c.janet_wrap_cfunction(self.toC()));
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
    supervisor_channel: *anyopaque,

    pub const Status = enum(c_int) {
        dead,
        @"error",
        debug,
        pending,
        user0,
        user1,
        user2,
        user3,
        user4,
        user5,
        user6,
        user7,
        user8,
        user9,
        new,
        alive,
    };

    pub fn toC(self: *Fiber) *c.JanetFiber {
        return @as(*c.JanetFiber, @ptrCast(self));
    }
    pub fn fromC(ptr: *c.JanetFiber) *Fiber {
        return @as(*Fiber, @ptrCast(ptr));
    }

    pub fn init(callee: *Function, capacity: i32, argv: []const Janet) *Fiber {
        return fromC(c.janet_fiber(
            callee.toC(),
            capacity,
            @as(i32, @intCast(argv.len)),
            @as([*c]const c.Janet, @ptrCast(argv.ptr)),
        ));
    }
    pub fn reset(self: *Fiber, callee: *Function, argv: []const Janet) *Fiber {
        return fromC(c.janet_fiber_reset(
            self.toC(),
            callee.toC(),
            @as(i32, @intCast(argv.len)),
            @as([*c]const c.Janet, @ptrCast(argv.ptr)),
        ));
    }
    pub fn status(self: *Fiber) Status {
        return @as(Status, @enumFromInt(c.janet_fiber_status(self.toC())));
    }
    pub fn currentFiber() *Fiber {
        return fromC(c.janet_current_fiber());
    }
    pub fn rootFiber() *Fiber {
        return fromC(c.janet_root_fiber());
    }

    pub fn wrap(self: *Fiber) Janet {
        return Janet.fromC(c.janet_wrap_fiber(self.toC()));
    }

    pub fn @"continue"(fiber: *Fiber, in: Janet, out: *Janet) Signal.Error!void {
        const signal = @as(
            *Signal,
            @ptrCast(&c.janet_continue(fiber.toC(), in.toC(), @as(*c.Janet, @ptrCast(out)))),
        ).*;
        switch (signal) {
            .ok => {},
            else => return signal.toError(),
        }
    }
    pub fn continueSignal(fiber: *Fiber, in: Janet, out: *Janet, sig: Signal) Signal.Error!void {
        const signal = @as(*Signal, @ptrCast(&c.janet_continue_signal(
            fiber.toC(),
            in.toC(),
            @as(*c.Janet, @ptrCast(out)),
            @as(*const c.JanetSignal, @ptrCast(&sig)).*,
        ))).*;
        switch (signal) {
            .ok => {},
            else => return signal.toError(),
        }
    }
    pub fn step(fiber: *Fiber, in: Janet, out: *Janet) Signal.Error!void {
        const signal = @as(
            *Signal,
            @ptrCast(&c.janet_step(fiber.toC(), in.toC(), @as(*c.Janet, @ptrCast(out)))),
        ).*;
        switch (signal) {
            .ok => {},
            else => return signal.toError(),
        }
    }
    pub fn stackstrace(fiber: *Fiber, err: Janet) void {
        c.janet_stacktrace(fiber.toC(), err.toC());
    }
    pub fn stackstraceExt(fiber: *Fiber, err: Janet, prefix: [*:0]const u8) void {
        c.janet_stacktrace_ext(fiber.toC(), err.toC(), prefix.ptr);
    }
};

pub const ListenerState = blk: {
    if (builtin.target.os.tag == .windows) {
        break :blk extern struct {
            machine: Listener,
            fiber: *Fiber,
            stream: *Stream,
            event: *anyopaque,
            tag: *anyopaque,
            bytes: c_int,
        };
    } else {
        break :blk extern struct {
            machine: Listener,
            fiber: *Fiber,
            stream: *Stream,
            event: *anyopaque,
            _index: usize,
            _mask: c_int,
            _next: *ListenerState,
        };
    }
};

pub const Handle = blk: {
    if (builtin.target.os.tag == .windows) {
        break :blk *anyopaque;
    } else {
        break :blk c_int;
    }
};

pub const HANDLE_NONE: Handle = blk: {
    if (builtin.target.os.tag == .windows) {
        break :blk null;
    } else {
        break :blk -1;
    }
};

pub const Stream = extern struct {
    handle: Handle,
    flags: u32,
    state: *ListenerState,
    methods: *const anyopaque,
    _mask: c_int,
};

pub const Listener = *const fn (state: *ListenerState, event: AsyncEvent) callconv(.C) AsyncStatus;

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

pub const MARSHAL_UNSAFE = c.JANET_MARSHAL_UNSAFE;
pub fn marshal(buf: *Buffer, x: Janet, rreg: *Environment, flags: c_int) void {
    c.janet_marshal(buf.toC(), x.toC(), rreg.toC(), flags);
}
pub fn unmarshal(bytes: []const u8, flags: c_int, reg: *Environment, next: [*]*const u8) Janet {
    return Janet.fromC(c.janet_unmarshal(
        bytes.ptr,
        bytes.len,
        flags,
        reg.toC(),
        @as([*c][*c]const u8, @ptrCast(next)),
    ));
}
pub const MarshalContext = extern struct {
    m_state: *anyopaque,
    u_state: *anyopaque,
    flags: c_int,
    data: [*]const u8,
    at: *AbstractType,

    pub fn toC(mc: *MarshalContext) *c.JanetMarshalContext {
        return @as(*c.JanetMarshalContext, @ptrCast(mc));
    }
    pub fn fromC(mc: *c.JanetMarshalContext) *MarshalContext {
        return @as(*MarshalContext, @ptrCast(mc));
    }

    pub fn marshal(ctx: *MarshalContext, comptime T: type, value: T) void {
        switch (T) {
            usize => c.janet_marshal_size(ctx.toC(), value),
            i32 => c.janet_marshal_int(ctx.toC(), value),
            i64 => c.janet_marshal_int64(ctx.toC(), value),
            u8 => c.janet_marshal_byte(ctx.toC(), value),
            []const u8 => c.janet_marshal_bytes(ctx.toC(), value.ptr, value.len),
            Janet => c.janet_marshal_janet(ctx.toC(), value.toC()),
            *anyopaque => c.janet_marshal_abstract(ctx.toC(), value),
            else => @compileError("Marshaling is not supported for '" ++ @typeName(T) ++ "'"),
        }
    }
    pub fn unmarshal(ctx: *MarshalContext, comptime T: type) T {
        return switch (T) {
            usize => c.janet_unmarshal_size(ctx.toC()),
            i32 => c.janet_unmarshal_int(ctx.toC()),
            i64 => c.janet_unmarshal_int64(ctx.toC()),
            u8 => c.janet_unmarshal_byte(ctx.toC()),
            Janet => Janet.fromC(c.janet_unmarshal_janet(ctx.toC())),
            *anyopaque => @compileError("Please use 'unmarshalAbstract' instead"),
            []u8, []const u8 => @compileError("Please use 'unmarshalBytes' instead"),
            else => @compileError("Unmarshaling is not supported for '" ++ @typeName(T) ++ "'"),
        };
    }

    pub fn unmarshalEnsure(ctx: *MarshalContext, size: usize) void {
        c.janet_unmarshal_ensure(ctx.toC(), size);
    }
    pub fn unmarshalBytes(ctx: *MarshalContext, dest: []u8) void {
        c.janet_unmarshal_bytes(ctx.toC(), dest.ptr, dest.len);
    }
    pub fn unmarshalAbstract(ctx: *MarshalContext, size: usize) *anyopaque {
        return c.janet_unmarshal_abstract(ctx.toC(), size) orelse unreachable;
    }
    pub fn unmarshalAbstractReuse(ctx: *MarshalContext, p: *anyopaque) void {
        c.janet_unmarshal_abstract_reuse(ctx.toC(), p);
    }
};

/// Specialized struct with typed pointers. `ValueType` must be the type of the actual value,
/// not the pointer to the value, for example, for direct C translation of `*c_void`, `ValueType`
/// must be `c_void`.
pub fn Abstract(comptime ValueType: type) type {
    return struct {
        ptr: *ValueType,

        const Self = @This();
        pub const Head = extern struct {
            gc: GCObject,
            type: *Type,
            size: usize,
            data: [*]c_longlong,
        };
        pub const Type = extern struct {
            name: [*:0]const u8,
            gc: ?*const fn (p: *ValueType, len: usize) callconv(.C) c_int = null,
            gc_mark: ?*const fn (p: *ValueType, len: usize) callconv(.C) c_int = null,
            get: ?*const fn (p: *ValueType, key: Janet, out: *Janet) callconv(.C) c_int = null,
            put: ?*const fn (p: *ValueType, key: Janet, value: Janet) callconv(.C) void = null,
            marshal: ?*const fn (p: *ValueType, ctx: *MarshalContext) callconv(.C) void = null,
            unmarshal: ?*const fn (ctx: *MarshalContext) callconv(.C) *ValueType = null,
            to_string: ?*const fn (p: *ValueType, buffer: *Buffer) callconv(.C) void = null,
            compare: ?*const fn (lhs: *ValueType, rhs: *ValueType) callconv(.C) c_int = null,
            hash: ?*const fn (p: *ValueType, len: usize) callconv(.C) i32 = null,
            next: ?*const fn (p: *ValueType, key: Janet) callconv(.C) Janet = null,
            call: ?*const fn (p: *ValueType, argc: i32, argv: [*]Janet) callconv(.C) Janet = null,

            pub fn toC(self: *const Type) *const c.JanetAbstractType {
                return @as(*const c.JanetAbstractType, @ptrCast(self));
            }
            pub fn fromC(p: *const c.JanetAbstractType) *const Type {
                return @as(*const Type, @ptrCast(p));
            }
            pub fn toVoid(self: *const Type) *const Abstract(anyopaque).Type {
                return @as(*const Abstract(anyopaque).Type, @ptrCast(self));
            }

            pub fn register(self: *const Type) void {
                c.janet_register_abstract_type(self.toC());
            }
        };

        pub fn toC(self: Self) *anyopaque {
            return @as(*anyopaque, @ptrCast(self.ptr));
        }
        pub fn fromC(p: *anyopaque) Self {
            return Self{ .ptr = @as(*ValueType, @ptrCast(@alignCast(p))) };
        }

        pub fn init(value: *const Type) Self {
            if (ValueType != anyopaque) {
                return fromC(c.janet_abstract(value.toC(), @sizeOf(ValueType)) orelse unreachable);
            } else {
                unreachable; // please use initVoid
            }
        }
        pub fn initFromPtr(value: *ValueType) Self {
            return Self{ .ptr = value };
        }
        pub fn initVoid(value: *const AbstractType, size: usize) Self {
            if (ValueType == anyopaque) {
                return fromC(c.janet_abstract(value.toC(), size) orelse unreachable);
            } else {
                unreachable; // please use init
            }
        }

        pub fn wrap(self: Self) Janet {
            return Janet.fromC(c.janet_wrap_abstract(self.toC()));
        }
        pub fn marshal(self: Self, ctx: *MarshalContext) void {
            c.janet_marshal_abstract(ctx.toC(), self.toC());
        }
        pub fn unmarshal(ctx: *MarshalContext) Self {
            if (ValueType != anyopaque) {
                return fromC(
                    c.janet_unmarshal_abstract(ctx.toC(), @sizeOf(ValueType)) orelse unreachable,
                );
            } else {
                unreachable; // please use unmarshalAbstract
            }
        }
    };
}

pub const VoidAbstract = Abstract(anyopaque);

/// Pure translation of a C struct with pointers *c_void.
pub const AbstractType = VoidAbstract.Type;

pub const Reg = extern struct {
    name: ?[*:0]const u8,
    cfun: ?CFunction.TypeImpl,
    documentation: ?[*:0]const u8 = null,

    pub const empty = Reg{ .name = null, .cfun = null };
};

pub const RegExt = extern struct {
    name: ?[*:0]const u8,
    cfun: ?CFunction.TypeImpl,
    documentation: ?[*:0]const u8 = null,
    source_file: ?[*:0]const u8 = null,
    source_line: i32 = 0,

    pub const empty = RegExt{ .name = null, .cfun = null };
};

pub const Method = extern struct {
    name: [*:0]const u8,
    cfun: CFunction.TypeImpl,
};

pub const View = extern struct {
    items: [*]const Janet,
    len: i32,

    pub fn slice(self: View) []const Janet {
        return self.items[0..@intCast(self.len)];
    }
};

pub const ByteView = extern struct {
    bytes: [*]const u8,
    len: i32,

    pub fn slice(self: ByteView) []const u8 {
        return self.bytes[0..@intCast(self.len)];
    }
};

pub const DictView = extern struct {
    kvs: [*]const KV,
    len: i32,
    cap: i32,

    pub fn slice(self: DictView) []const KV {
        return self.kvs[0..@intCast(self.cap)];
    }
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

test "refAllDecls" {
    testing.refAllDecls(@This());
    testing.refAllDecls(JanetMixin);
    testing.refAllDecls(String);
    testing.refAllDecls(Symbol);
    testing.refAllDecls(Keyword);
    testing.refAllDecls(Array);
    testing.refAllDecls(Buffer);
    testing.refAllDecls(Table);
    testing.refAllDecls(Struct);
    testing.refAllDecls(Tuple);
    testing.refAllDecls(Abstract(anyopaque));
    testing.refAllDecls(Function);
    testing.refAllDecls(CFunction);
    testing.refAllDecls(Environment);
    testing.refAllDecls(MarshalContext);
}

test "hello world" {
    try init();
    defer deinit();
    const env = Environment.coreEnv(null);
    _ = try env.doString("(print `hello, world!`)", "main");
}

test "unwrap values" {
    try init();
    defer deinit();
    const env = Environment.coreEnv(null);
    {
        const value = try env.doString("1", "main");
        try testing.expectEqual(@as(i32, 1), try value.unwrap(i32));
    }
    {
        const value = try env.doString("1", "main");
        try testing.expectEqual(@as(f64, 1), try value.unwrap(f64));
    }
    {
        const value = try env.doString("true", "main");
        try testing.expectEqual(true, try value.unwrap(bool));
    }
    {
        const value = try env.doString("\"str\"", "main");
        try testing.expectEqualStrings("str", (try value.unwrap(String)).slice);
    }
    {
        const value = try env.doString(":str", "main");
        try testing.expectEqualStrings("str", (try value.unwrap(Keyword)).slice);
    }
    {
        const value = try env.doString("'str", "main");
        try testing.expectEqualStrings("str", (try value.unwrap(Symbol)).slice);
    }
    {
        const value = try env.doString("[58 true 36.0]", "main");
        const tuple = try value.unwrap(Tuple);
        try testing.expectEqual(@as(i32, 3), tuple.head().length);
        try testing.expectEqual(@as(usize, 3), tuple.slice.len);
        try testing.expectEqual(@as(i32, 58), try tuple.slice[0].unwrap(i32));
        try testing.expectEqual(true, try tuple.slice[1].unwrap(bool));
        try testing.expectEqual(@as(f64, 36), try tuple.slice[2].unwrap(f64));
    }
    {
        const value = try env.doString("@[58 true 36.0]", "main");
        const array = try value.unwrap(*Array);
        try testing.expectEqual(@as(i32, 3), array.count);
        try testing.expectEqual(@as(i32, 58), try array.data[0].unwrap(i32));
        try testing.expectEqual(true, try array.data[1].unwrap(bool));
        try testing.expectEqual(@as(f64, 36), try array.data[2].unwrap(f64));
    }
    {
        const value = try env.doString("@\"str\"", "main");
        const buffer = try value.unwrap(*Buffer);
        try testing.expectEqual(@as(i32, 3), buffer.count);
        try testing.expectEqual(@as(u8, 's'), buffer.data[0]);
        try testing.expectEqual(@as(u8, 't'), buffer.data[1]);
        try testing.expectEqual(@as(u8, 'r'), buffer.data[2]);
    }
    {
        const value = try env.doString("{:kw 2 'sym 8 98 56}", "main");
        _ = try value.unwrap(Struct);
    }
    {
        const value = try env.doString("@{:kw 2 'sym 8 98 56}", "main");
        _ = try value.unwrap(*Table);
    }
    {
        const value = try env.doString("marshal", "main");
        _ = try value.unwrap(CFunction);
    }
    {
        const value = try env.doString("+", "main");
        _ = try value.unwrap(*Function);
    }
    {
        const value = try env.doString("(file/temp)", "main");
        _ = try value.unwrapAbstract(anyopaque);
    }
    {
        const value = try env.doString("(fiber/current)", "main");
        _ = try value.unwrap(*Fiber);
    }
}

test "janet_type" {
    try init();
    defer deinit();
    const env = Environment.coreEnv(null);
    const value = try env.doString("1", "main");
    try testing.expectEqual(Janet.Type.number, value.janetType());
}

test "janet_checktypes" {
    try init();
    defer deinit();
    const env = Environment.coreEnv(null);
    {
        const value = try env.doString("1", "main");
        try testing.expectEqual(true, value.checkTypes(TFLAG_NUMBER));
    }
    {
        const value = try env.doString(":str", "main");
        try testing.expectEqual(true, value.checkTypes(TFLAG_BYTES));
    }
}

test "struct" {
    try init();
    defer deinit();
    const env = Environment.coreEnv(null);
    const value = try env.doString("{:kw 2 'sym 8 98 56}", "main");
    const st = try value.unwrap(Struct);
    const first_kv = st.get(keyword("kw")).?;
    const second_kv = st.get(symbol("sym")).?;
    const third_kv = st.get(wrap(i32, 98)).?;
    try testing.expectEqual(@as(i32, 3), st.head().length);
    try testing.expectEqual(@as(i32, 2), try first_kv.unwrap(i32));
    try testing.expectEqual(@as(i32, 8), try second_kv.unwrap(i32));
    try testing.expectEqual(@as(i32, 56), try third_kv.unwrap(i32));
    if (st.get(wrap(i32, 123))) |_| return error.MustBeNull;
}

test "table" {
    try init();
    defer deinit();
    {
        const env = Environment.coreEnv(null);
        const value = try env.doString("@{:kw 2 'sym 8 98 56}", "main");
        const table = try value.unwrap(*Table);
        const first_kv = table.get(keyword("kw")).?;
        const second_kv = table.get(symbol("sym")).?;
        const third_kv = table.get(wrap(i32, 98)).?;
        try testing.expectEqual(@as(i32, 3), table.count);
        try testing.expectEqual(@as(i32, 2), try first_kv.unwrap(i32));
        try testing.expectEqual(@as(i32, 8), try second_kv.unwrap(i32));
        try testing.expectEqual(@as(i32, 56), try third_kv.unwrap(i32));
        if (table.get(wrap(i32, 123))) |_| return error.MustBeNull;
    }
    {
        var table = Table.initDynamic(5);
        table.put(keyword("apples"), wrap(i32, 2));
        table.put(keyword("oranges"), wrap(i32, 8));
        table.put(keyword("peaches"), wrap(i32, 1));
        const apples = table.get(keyword("apples")).?;
        try testing.expectEqual(@as(i32, 2), try apples.unwrap(i32));
        var which_table: *Table = undefined;
        const oranges = table.getEx(keyword("oranges"), &which_table).?;
        try testing.expectEqual(@as(i32, 8), try oranges.unwrap(i32));
        try testing.expectEqual(table, which_table);
        const peaches = table.rawGet(keyword("peaches")).?;
        try testing.expectEqual(@as(i32, 1), try peaches.unwrap(i32));
        _ = table.remove(keyword("peaches"));
        if (table.get(keyword("peaches"))) |_| return error.MustBeNull;
    }
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
    const st_abstract = ZigStructAbstract.init(&zig_struct_abstract_type);
    const n = opt(u32, argv, argc, 1, 1);
    st_abstract.ptr.counter = n;
    return st_abstract.wrap();
}

/// `inc` wrapper which receives a struct and a number to increase the `counter` to.
fn cfunInc(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixArity(argc, 2);
    var st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    const n = get(u32, argv, 1);
    st_abstract.ptr.inc(n);
    return nil();
}

/// `dec` wrapper which fails if we try to decrease the `counter` below 0.
fn cfunDec(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixArity(argc, 1);
    var st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    st_abstract.ptr.dec() catch {
        panic("expected failure, part of the test");
    };
    return nil();
}

/// Simple getter returning an integer value.
fn cfunGetcounter(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixArity(argc, 1);
    const st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    return wrap(i32, @as(i32, @bitCast(st_abstract.ptr.counter)));
}

const zig_struct_cfuns = [_]Reg{
    Reg{ .name = "struct-init", .cfun = &cfunZigStruct },
    Reg{ .name = "inc", .cfun = &cfunInc },
    Reg{ .name = "dec", .cfun = &cfunDec },
    Reg{ .name = "get-counter", .cfun = &cfunGetcounter },
    Reg.empty,
};

test "abstract initialized inside Janet" {
    try init();
    defer deinit();
    var env = Environment.coreEnv(null);
    env.cfunsPrefix("zig", &zig_struct_cfuns);
    _ = try env.doString("(def st (zig/struct-init))", "main");
    // Default value is 1 if not supplied with the initializer.
    _ = try env.doString("(assert (= (zig/get-counter st) 1))", "main");
    _ = try env.doString("(zig/dec st)", "main");
    _ = try env.doString("(assert (= (zig/get-counter st) 0))", "main");
    // Expected fail of dec function.
    try testing.expectError(error.RuntimeError, env.doString("(zig/dec st)", "main"));
    _ = try env.doString("(assert (= (zig/get-counter st) 0))", "main");
    _ = try env.doString("(zig/inc st 5)", "main");
    _ = try env.doString("(assert (= (zig/get-counter st) 5))", "main");
}

test "abstract injected from Zig" {
    try init();
    defer deinit();
    var env = Environment.coreEnv(null);
    env.cfunsPrefix("zig", &zig_struct_cfuns);
    var st_abstract = ZigStructAbstract.init(&zig_struct_abstract_type);
    st_abstract.ptr.* = ZigStruct{ .counter = 2 };
    env.def("st", st_abstract.wrap(), null);
    _ = try env.doString("(assert (= (zig/get-counter st) 2))", "main");
    st_abstract.ptr.counter = 1;
    _ = try env.doString("(assert (= (zig/get-counter st) 1))", "main");
    _ = try env.doString("(zig/dec st)", "main");
    try testing.expectEqual(@as(u32, 0), st_abstract.ptr.counter);
}

// We need an allocator to pass to the Zig struct.
const AllyAbstractType = Abstract(std.mem.Allocator).Type{ .name = "zig-allocator" };

/// Initializer to make Zig's allocator into existence.
fn cfunInitZigAllocator(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    _ = argv;
    fixArity(argc, 0);
    const ally_abstract = Abstract(std.mem.Allocator).init(&AllyAbstractType);
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
    pub fn init(ally: std.mem.Allocator) ComplexZigStruct {
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
    const k = key.unwrap(Keyword) catch {
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
    const k = key.unwrap(Keyword) catch {
        panic("Not a keyword");
    };
    // HACK: allocating the key to be stored in our struct's `storage` via Janet's allocation
    // function which is never freed. I'm too lazy to implement allocating and deallocating of
    // strings via Zig's allocator, sorry.
    var allocated_key = @as(
        [*]u8,
        @ptrCast(@alignCast(malloc(@intCast(k.slice.len)))),
    )[0..@intCast(k.slice.len)];
    std.mem.copy(u8, allocated_key, k.slice);
    st.storage.put(allocated_key, value) catch {
        panic("Out of memory");
    };
}
// We only marshal the counter, the `storage` is lost, as well as allocator.
fn czsMarshal(st: *ComplexZigStruct, ctx: *MarshalContext) callconv(.C) void {
    var ally = st.storage.allocator;
    Abstract(ComplexZigStruct).initFromPtr(st).marshal(ctx);
    // HACK: we can't marshal more than one abstract type, so we marshal the pointer as integer
    // since the allocator is global and will not change its pointer during program execution.
    ctx.marshal(usize, @intFromPtr(&ally));
    ctx.marshal(i32, st.counter);
}
fn czsUnmarshal(ctx: *MarshalContext) callconv(.C) *ComplexZigStruct {
    const st_abstract = Abstract(ComplexZigStruct).unmarshal(ctx);
    const allyp = ctx.unmarshal(usize);
    const ally = @as(*std.mem.Allocator, @ptrFromInt(allyp));
    const counter = ctx.unmarshal(i32);
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
            return keyword(next_key.*);
        } else {
            return nil();
        }
    } else {
        const str_key = key.unwrap(Keyword) catch {
            panic("Not a keyword");
        };
        var it = st.storage.keyIterator();
        while (it.next()) |k| {
            if (std.mem.eql(u8, k.*, str_key.slice)) {
                if (it.next()) |next_key| {
                    return keyword(next_key.*);
                } else {
                    return nil();
                }
            }
        } else {
            return nil();
        }
    }
    unreachable;
}
// We set the counter to the supplied value.
fn czsCall(st: *ComplexZigStruct, argc: i32, argv: [*]Janet) callconv(.C) Janet {
    fixArity(argc, 1);
    const new_counter = get(i32, argv, 0);
    st.counter = new_counter;
    return wrap(bool, true);
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
    fixArity(argc, 1);
    const st_abstract = Abstract(ComplexZigStruct).init(&complex_zig_struct_abstract_type);
    const ally_abstract = getAbstract(argv, 0, std.mem.Allocator, &AllyAbstractType);
    st_abstract.ptr.* = ComplexZigStruct.init(ally_abstract.ptr.*);
    return st_abstract.wrap();
}
/// Simple getter returning an integer value.
fn cfunGetComplexCounter(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixArity(argc, 1);
    const st_abstract = getAbstract(argv, 0, ComplexZigStruct, &complex_zig_struct_abstract_type);
    return wrap(i32, st_abstract.ptr.counter);
}

const complex_zig_struct_cfuns = [_]Reg{
    Reg{ .name = "complex-struct-init", .cfun = &cfunComplexZigStruct },
    Reg{ .name = "get-counter", .cfun = &cfunGetComplexCounter },
    Reg{ .name = "alloc-init", .cfun = &cfunInitZigAllocator },
    Reg.empty,
};

test "complex abstract" {
    try init();
    // Testing `gc` function implementation. The memory for our abstract type is allocated
    // with testing.allocator, so the test will fail if we leak memory. And here Janet is
    // responsible for freeing all the allocated memory on deinit.
    defer deinit();
    complex_zig_struct_abstract_type.register();
    var env = Environment.coreEnv(null);
    env.cfunsPrefix("zig", &complex_zig_struct_cfuns);
    // Init our `testing.allocator` as a Janet abstract type.
    _ = try env.doString("(def ally (zig/alloc-init))", "main");
    // Init our complex struct which requires a Zig allocator.
    _ = try env.doString("(def st (zig/complex-struct-init ally))", "main");
    _ = try env.doString("(assert (= (zig/get-counter st) 0))", "main");
    // Testing `get` implementation.
    _ = try env.doString("(assert (= (get st :me) nil))", "main");
    // Testing `put` implementation.
    _ = try env.doString("(put st :me [1 2 3])", "main");
    // Testing `gcMark` implementation. If we don't implement gcMark, GC will collect [1 2 3]
    // tuple and Janet will panic trying to retrieve it.
    _ = try env.doString("(gccollect)", "main");
    _ = try env.doString("(assert (= (get st :me) [1 2 3]))", "main");
    // Testing `call` implementation.
    _ = try env.doString("(st 5)", "main");
    _ = try env.doString("(assert (= (zig/get-counter st) 5))", "main");
    // Testing marshaling.
    _ = try env.doString("(def marshaled (marshal st))", "main");
    _ = try env.doString("(def unmarshaled (unmarshal marshaled))", "main");
    _ = try env.doString("(assert (= (zig/get-counter unmarshaled) 5))", "main");
    // Testing `compare` implementation.
    _ = try env.doString("(assert (= (zig/get-counter st) 5))", "main");
    _ = try env.doString("(assert (= (zig/get-counter unmarshaled) 5))", "main");
    _ = try env.doString("(assert (compare= unmarshaled st))", "main");
    _ = try env.doString("(st 3)", "main");
    _ = try env.doString("(assert (compare> unmarshaled st))", "main");
    // Testing `hash` implementation.
    _ = try env.doString("(assert (= (hash st) 1337))", "main");
    // Testing `next` implementation.
    _ = try env.doString("(put st :mimi 42)", "main");
    _ = try env.doString(
        \\(eachp [k v] st
        \\  (assert (or (and (= k :me)   (= v [1 2 3]))
        \\              (and (= k :mimi) (= v 42)))))
    ,
        "main",
    );
}

test "function call" {
    try init();
    defer deinit();
    const env = Environment.coreEnv(null);
    const value = try env.doString("+", "main");
    const func = try value.unwrap(*Function);
    var sum: Janet = undefined;
    try func.pcall(&[_]Janet{ wrap(i32, 2), wrap(i32, 2) }, &sum, null);
    try testing.expectEqual(@as(i32, 4), try sum.unwrap(i32));
}

pub const ParserStatus = enum(c_int) {
    root = 0,
    @"error" = 1,
    pending = 2,
    dead = 3,
};

pub const Parser = struct {
    inner: c.JanetParser,

    pub fn init() Parser {
        var self: Parser = undefined;
        c.janet_parser_init(&self.inner);
        return self;
    }
    pub fn deinit(self: *Parser) void {
        c.janet_parser_deinit(&self.inner);
    }
    pub fn consume(self: *Parser, char: u8) void {
        return c.janet_parser_consume(&self.inner, char);
    }
    pub fn status(self: *Parser) ParserStatus {
        return @enumFromInt(c.janet_parser_status(&self.inner));
    }
    pub fn produce(self: *Parser) Janet {
        return Janet.fromC(c.janet_parser_produce(&self.inner));
    }
    pub fn produceWrapped(self: *Parser) Janet {
        return Janet.fromC(c.janet_parser_produce_wrapped(&self.inner));
    }
    pub fn @"error"(self: *Parser) ?[*:0]const u8 {
        return c.janet_parser_error(&self.inner);
    }
    pub fn flush(self: *Parser) void {
        return c.janet_parser_flush(&self.inner);
    }
    pub fn eof(self: *Parser) void {
        return c.janet_parser_eof(&self.inner);
    }
    pub fn hasMore(self: *Parser) bool {
        return 0 != c.janet_parser_has_more(&self.inner);
    }
};

test "Parser" {
    try init();
    defer deinit();
    var parser = Parser.init();
    defer parser.deinit();
    parser.consume(0);
    _ = parser.status();
    _ = parser.produce();
    _ = parser.produceWrapped();
    _ = parser.@"error"();
    _ = parser.flush();
    _ = parser.eof();
    _ = parser.hasMore();
}
