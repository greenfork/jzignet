const std = @import("std");
pub usingnamespace @import("jzignet");

fn cfunAddNumbers(argc: i32, argv: [*]const Janet) callconv(.C) Janet {
    fixarity(argc, 2);
    const n1 = getNumber(argv, 0);
    const n2 = getNumber(argv, 1);
    return wrapNumber(n1 + n2);
}

const cfuns_zig = [_]Reg{
    Reg{ .name = "add-numbers", .cfun = cfunAddNumbers },
    Reg.empty,
};

pub fn main() anyerror!void {
    try init();
    defer deinit();
    const env = coreEnv(null);
    cfunsPrefix(env, "zig", &cfuns_zig);
    var value: Janet = undefined;
    try doString(env, "(zig/add-numbers 42 69)", "main", &value);
    const number = value.unwrapNumber();
    std.log.info("the true answer is {d}\n", .{number});
}
