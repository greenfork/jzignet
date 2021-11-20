const std = @import("std");
const testing = std.testing;
const j = @import("jzignet");

// Source Zig code

pub const ZigStruct = struct {
    counter: u32,

    pub fn add(self: *ZigStruct, a: u32) void {
        self.counter += a;
    }
};

// Wrapper code

const ZigStructAbstract = j.Abstract(ZigStruct);
const zig_struct_abstract_type = ZigStructAbstract.Type{ .name = "zig-struct" };

fn cfunInitStruct(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    _ = argv;
    j.fixarity(argc, 0);
    const st_abstract = j.abstract(ZigStruct, &zig_struct_abstract_type);
    st_abstract.ptr.* = ZigStruct{ .counter = 1 };
    return st_abstract.wrap();
}

fn cfunAdd(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    j.fixarity(argc, 2);
    var st_abstract = j.getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    const n = j.getNat(argv, 1);
    st_abstract.ptr.add(@intCast(u32, n));
    return j.wrapNil();
}

fn cfunGetCounter(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    j.fixarity(argc, 1);
    const st_abstract = j.getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);
    return j.wrapInteger(@bitCast(i32, st_abstract.ptr.counter));
}

const cfuns_zig = [_]j.Reg{
    j.Reg{ .name = "init-struct", .cfun = cfunInitStruct },
    j.Reg{ .name = "add", .cfun = cfunAdd },
    j.Reg{ .name = "get-counter", .cfun = cfunGetCounter },
    j.Reg.empty,
};

export fn _janet_mod_config() j.BuildConfig {
    return j.configCurrent();
}

export fn _janet_init(env: *j.Table) void {
    j.cfuns(env, "zig_module", &cfuns_zig);
}

test "refAllDecls" {
    testing.refAllDecls(@This());
}
