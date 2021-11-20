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
    j.fixarity(argc, 2);

    // Retrieve these arguments.
    const n1 = j.getNumber(argv, 0);
    const n2 = j.getNumber(argv, 1);

    // Return back a Janet value.
    return j.wrapNumber(n1 + n2);
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
    const env = j.coreEnv(null);

    // Import previously defined Zig functions into Janet with a `zig/` prefix.
    j.cfunsPrefix(env, "zig", &cfuns_zig);

    // Allocate a Janet value on the stack for a return.
    var value: j.Janet = undefined;

    // Use our function and save result to `value`.
    try j.doString(env, "(zig/add-numbers 42 69)", "main", &value);

    // Transform our result from Janet object into an integer.
    const number = value.unwrapNumber();

    // Ta-dam!
    std.debug.print("the true answer is {d}\n", .{number});
}
