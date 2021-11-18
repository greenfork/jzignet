const std = @import("std");
const testing = std.testing;
pub usingnamespace @import("jzignet");

// Source Zig code

pub const ZigStruct = struct {
    counter: u32,

    pub fn add(self: *ZigStruct, a: u32) void {
        self.counter += a;
    }
};

// wrapper code

const ZigStructAbstract = Abstract(ZigStruct);
const zig_struct_abstract_type = ZigStructAbstract.Type{ .name = "zig-struct" };

fn cfunInitStruct(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 0);
    const st_abstract = abstract(ZigStruct, &zig_struct_abstract_type);
    st_abstract.ptr.* = ZigStruct{ .counter = 1 };
    return st_abstract.wrap();
}

fn cfunAdd(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 2);
    var st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    const n = getNat(argv, 1);
    st_abstract.ptr.add(@intCast(u32, n));
    return wrapNil();
}

fn cfunGetCounter(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 1);
    const st_abstract = getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    return wrapInteger(@bitCast(i32, st_abstract.ptr.counter));
}

const cfuns_zig = [_]Reg{
    Reg{ .name = "init-struct", .cfun = cfunInitStruct },
    Reg{ .name = "add", .cfun = cfunAdd },
    Reg{ .name = "get-counter", .cfun = cfunGetCounter },
    Reg.empty,
};

export fn _janet_mod_config() BuildConfig {
    return configCurrent();
}

export fn _janet_init(env: *Table) void {
    cfuns(env, "mylib", &cfuns_zig);
}

test "refAllDecls" {
    testing.refAllDecls(@This());
}
