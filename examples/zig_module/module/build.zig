const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    // Add the library to the compilation unit but specify correct paths.
    var ally = b.allocator;
    const janet_lib = b.addStaticLibrary("janet", null);
    var janet_flags = std.ArrayList([]const u8).init(ally);
    janet_flags.appendSlice(&[_][]const u8{"-std=c99"}) catch unreachable;
    if (mode != .Debug) {
        janet_flags.appendSlice(&[_][]const u8{ "-O2", "-flto" }) catch unreachable;
    }
    janet_lib.addCSourceFile("../../../c/janet.c", janet_flags.items);
    janet_lib.linkLibC();
    janet_lib.setBuildMode(mode);

    const static_lib = b.addStaticLibrary("zig_module", "src/main.zig");
    // This is necessary because by default it is not included in static library builds.
    static_lib.bundle_compiler_rt = true;
    static_lib.setBuildMode(mode);
    static_lib.linkLibrary(janet_lib);
    static_lib.addPackagePath("jzignet", "../../../src/janet.zig");
    static_lib.addIncludeDir("../../../c");
    static_lib.install();

    const dynamic_lib = b.addSharedLibrary("zig_module", "src/main.zig", .unversioned);
    dynamic_lib.setBuildMode(mode);
    dynamic_lib.linkLibrary(janet_lib);
    dynamic_lib.addPackagePath("jzignet", "../../../src/janet.zig");
    dynamic_lib.addIncludeDir("../../../c");
    dynamic_lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    // Don't forget to do same in tests.
    main_tests.linkLibrary(janet_lib);
    main_tests.addPackagePath("jzignet", "../../../src/janet.zig");
    main_tests.addIncludeDir("../../../c");
    main_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
