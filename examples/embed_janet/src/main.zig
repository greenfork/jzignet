const std = @import("std");
const j = @import("jzignet");

comptime {
    const current_version = std.SemanticVersion.parse("0.8.1") catch unreachable;
    const comparison = @import("builtin").zig_version.order(current_version);
    if (comparison == .lt) @compileError("Zig version must be at least 0.8.1");
}

fn cfunAddNumbers(argc: i32, argv: [*]const j.Janet) callconv(.C) j.Janet {
    j.fixarity(argc, 2);
    const n1 = j.getNumber(argv, 0);
    const n2 = j.getNumber(argv, 1);
    return j.wrapNumber(n1 + n2);
}

const cfuns_zig = [_]j.Reg{
    j.Reg{ .name = "add-numbers", .cfun = cfunAddNumbers },
    j.Reg.empty,
};

pub fn main() anyerror!void {
    try j.init();
    defer j.deinit();
    const env = j.coreEnv(null);
    j.cfunsPrefix(env, "zig", &cfuns_zig);
    var value: j.Janet = undefined;
    try j.doString(env, "(zig/add-numbers 42 69)", "main", &value);
    const number = value.unwrapNumber();
    std.log.info("the true answer is {d}", .{number});
}
