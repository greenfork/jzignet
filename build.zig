const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const janet_lib = b.addStaticLibrary("janet", null);
    janet_lib.addCSourceFile(
        "c/janet.c",
        &[_][]const u8{ "-std=c99", "-O2", "-flto", "-Wall", "-Wextra", "-fvisibility=hidden" },
    );
    janet_lib.linkLibC();
    janet_lib.setBuildMode(mode);

    const lib = b.addStaticLibrary("jzignet", "src/janet.zig");
    lib.addIncludeDir("c");
    lib.linkLibC();
    lib.linkLibrary(janet_lib);
    lib.setBuildMode(mode);
    // lib.install();

    var tests = b.addTest("src/janet.zig");
    tests.setBuildMode(mode);
    tests.addIncludeDir("c");
    tests.addIncludeDir("c");
    tests.linkLibC();
    tests.linkLibrary(janet_lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);
}
