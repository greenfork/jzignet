const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const janet_lib = b.addStaticLibrary("janet", null);
    const janet_flags = blk: {
        if (mode == .Debug) {
            break :blk &[_][]const u8{ "-std=c99", "-Wall", "-Wextra", "-fvisibility=hidden" };
        } else {
            break :blk &[_][]const u8{ "-std=c99", "-Wall", "-Wextra", "-fvisibility=hidden", "-O2", "-flto" };
        }
    };
    janet_lib.addCSourceFile("c/janet.c", janet_flags);
    janet_lib.linkLibC();
    janet_lib.setBuildMode(mode);

    const lib = b.addStaticLibrary("jzignet", "src/janet.zig");
    lib.setBuildMode(mode);
    lib.addIncludeDir("c");
    lib.linkLibC();
    lib.linkLibrary(janet_lib);
    lib.install();

    var tests = b.addTest("src/janet.zig");
    tests.setBuildMode(mode);
    tests.addIncludeDir("c");
    tests.linkLibC();
    tests.linkLibrary(janet_lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);
}
