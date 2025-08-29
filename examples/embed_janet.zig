//! # Example: Embed Janet into Zig
//!
//! If you don't have Zig installed, you can download it from the official Zig
//! website <https://ziglang.org/download/>. You don't need to install Janet,
//! Janet is built into this library.

const std = @import("std");
const j = @import("jzignet");

// Function with a standard signature which can be imported to Janet.
fn cfunAddNumbers(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    // Check that the function receives only 2 arguments.
    j.fixArity(argc, 2);

    // Retrieve these arguments.
    const n1 = j.get(i32, argv, 0);
    const n2 = j.get(i32, argv, 1);

    // Return back a Janet value.
    return j.wrap(i32, n1 + n2);
}

// Declare all the functions which will be imported to Janet.
const cfuns_zig = [_]j.Reg{
    j.Reg{ .name = "add-numbers", .cfun = cfunAddNumbers },
    j.Reg.empty,
};

pub fn main() anyerror!void {
    // Initialize and deinitialize the Janet virtual machine.
    try j.init();
    defer j.deinit();

    // Get the standard root environment.
    const env = j.Environment.coreEnv(null);

    // Import previously defined Zig functions into Janet with a `zig/` prefix.
    env.cfunsPrefix("zig", &cfuns_zig);

    // Use our function and save result to `value`.
    const value = try env.doString("(zig/add-numbers 42 69)", "main");

    // Transform our result from Janet object into an integer.
    const number = try value.unwrap(i32);

    // Ta-dam!
    std.debug.print("Running embed_janet: the true answer is {d}\n", .{number});
}
