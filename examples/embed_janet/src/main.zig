const std = @import("std");
const j = @import("jzignet");

// Check the version, just for a more friendly error message in case Zig version
// is too small.
comptime {
    const current_version = std.SemanticVersion.parse("0.8.1") catch unreachable;
    const comparison = @import("builtin").zig_version.order(current_version);
    if (comparison == .lt) @compileError("Zig version must be at least 0.8.1");
}

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
    const number = value.unwrap(i32);

    // Ta-dam!
    std.debug.print("the true answer is {d}\n", .{number});
}
