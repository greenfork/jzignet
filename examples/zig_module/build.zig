const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();

    // Add the library to the compilation unit but specify correct paths.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var ally = &arena.allocator;
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
    janet_lib.addCSourceFile("../../c/janet.c", janet_flags.items);
    janet_lib.linkLibC();
    janet_lib.setBuildMode(mode);

    const lib = b.addStaticLibrary("zig_module", "src/main.zig");
    lib.setBuildMode(mode);

    // Link library to your library.
    lib.linkLibrary(janet_lib);
    lib.addPackage(.{ .name = "jzignet", .path = "../../src/janet.zig" });
    lib.addIncludeDir("../../c");

    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    // Don't forget to do same in tests.
    main_tests.linkLibrary(janet_lib);
    main_tests.addPackage(.{ .name = "jzignet", .path = "../../src/janet.zig" });
    main_tests.addIncludeDir("../../c");
    main_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
