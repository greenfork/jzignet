const std = @import("std");
const j = @import("jzignet");

comptime {
    const current_version = std.SemanticVersion.parse("0.9.0-dev.1678+7747bf07c") catch unreachable;
    const comparison = @import("builtin").zig_version.order(current_version);
    if (comparison == .lt) @compileError("Zig version must be at least as of 2021-11-18");
}

// Source Zig code
//=================

// This is a very simple Zig structure we will be using from Janet.
pub const ZigStruct = struct {
    counter: u32,

    pub fn add(self: *ZigStruct, a: u32) void {
        self.counter += a;
    }
};

// Wrapper code
//==============

// `ZigStruct` is wrapped into an "abstract type" which is a Janet concept
// for a generic value, it seems to map well to Zig structs.
const ZigStructAbstract = j.Abstract(ZigStruct);
const zig_struct_abstract_type = ZigStructAbstract.Type{ .name = "zig-struct" };

// Function with a standard signature which can be imported to Janet.
fn cfunInitStruct(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    _ = argv;
    // Check that the function receives no arguments.
    j.fixArity(argc, 0);

    // Allocate and create an abstract type.
    const st_abstract = ZigStructAbstract.init(&zig_struct_abstract_type);

    // Assign the allocated memory with our initialized struct.
    st_abstract.ptr.* = ZigStruct{ .counter = 1 };

    // Return the abstract as a Janet value.
    return st_abstract.wrap();
}

// Function with a standard signature which can be imported to Janet.
fn cfunAdd(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    // Check that the function receives exactly 2 arguments.
    j.fixArity(argc, 2);

    // Retrieve the abstract type from the first argument.
    var st_abstract = j.getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);

    // Retrieve a natural number from the second argument.
    const n = j.get(u32, argv, 1);

    // Call the `add` function from `ZigStruct`. Notice that we need to reference `ptr`
    // to get to the actual pointer for our struct, `st_abstract` is from Janet world.
    st_abstract.ptr.add(n);

    // Return nil.
    return j.nil();
}

// Function with a standard signature which can be imported to Janet.
fn cfunGetCounter(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    // Check that the function receives exactly 1 argument.
    j.fixArity(argc, 1);

    // Retrieve the abstract type from the first argument.
    const st_abstract = j.getAbstract(argv, 0, ZigStruct, &zig_struct_abstract_type);

    // Return the counter. Notice the use of `ptr` to get to the actual Zig pointer.
    return j.wrap(u32, st_abstract.ptr.counter);
}

// Declare all the functions which will be imported to Janet.
const cfuns_zig = [_]j.Reg{
    j.Reg{ .name = "init-struct", .cfun = cfunInitStruct },
    j.Reg{ .name = "add", .cfun = cfunAdd },
    j.Reg{ .name = "get-counter", .cfun = cfunGetCounter },
    j.Reg.empty,
};

// C ABI code
//============

// Exactly this function must be exported from a static or dynamic library built by Zig.
// It tells the Janet version used for building this module.
export fn _janet_mod_config() j.BuildConfig {
    return j.configCurrent();
}

// Exactly this function with this signature must be exported from a Zig library.
// In the body of this function you can do whatever you want, the main purpose
// is to modify the `env` parameter by importing functions and variables into it.
export fn _janet_init(env: *j.Environment) void {
    // Import previously defined Zig functions into `env`.
    env.cfuns("zig_module", &cfuns_zig);
}

// This function must mirror the `_janet_init` and it is used by static compilation.
// The name must be exactly as specified in `project.janet`:
// `:static-entry "janet_module_entry_zig_module"`.
export fn janet_module_entry_zig_module(env: *j.Environment) void {
    // Import previously defined Zig functions into `env`.
    env.cfuns("zig_module", &cfuns_zig);
}

// Testing
//=========

test "refAllDecls" {
    std.testing.refAllDecls(@This());
}
