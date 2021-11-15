const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var ally = &arena.allocator;

    const mode = b.standardReleaseOptions();
    const no_nanbox = b.option(bool, "no_nanbox", "Do not use nanbox implementation of Janet (default false)") orelse false;

    const janet_lib = b.addStaticLibrary("janet", null);
    var janet_flags = std.ArrayList([]const u8).init(ally);
    try janet_flags.appendSlice(&[_][]const u8{
        "-std=c99",
        "-Wall",
        "-Wextra",
        "-fvisibility=hidden",
    });
    if (mode != .Debug) {
        try janet_flags.appendSlice(&[_][]const u8{ "-O2", "-flto" });
    }
    if (no_nanbox) {
        try janet_flags.appendSlice(&[_][]const u8{"-DJANET_NO_NANBOX"});
    }
    janet_lib.addCSourceFile("c/janet.c", janet_flags.items);
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
