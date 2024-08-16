const std = @import("std");

pub fn build(b: *std.Build) void {
    const ally = b.allocator;

    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const no_nanbox = b.option(bool, "no_nanbox", "Do not use nanbox implementation of Janet (default false)") orelse false;

    const c_header = b.addTranslateC(.{
        .root_source_file = b.path("c/janet.h"),
        .optimize = optimize,
        .target = target,
    });

    const mod = b.addModule("jzignet", .{
        .root_source_file = b.path("src/janet.zig"),
        .imports = &.{.{ .name = "cjanet", .module = c_header.createModule() }},
    });

    const lib = b.addStaticLibrary(.{
        .name = "jzignet",
        .optimize = optimize,
        .target = target,
    });

    var janet_flags = std.ArrayList([]const u8).init(ally);
    janet_flags.appendSlice(&[_][]const u8{"-std=c99"}) catch unreachable;
    if (optimize != .Debug) {
        janet_flags.appendSlice(&[_][]const u8{ "-O2", "-flto" }) catch unreachable;
    }
    if (no_nanbox) {
        janet_flags.appendSlice(&[_][]const u8{"-DJANET_NO_NANBOX"}) catch unreachable;
    }
    lib.linkLibC();
    lib.addIncludePath(b.path("c"));
    lib.addCSourceFile(.{ .file = b.path("c/janet.c"), .flags = janet_flags.items });
    b.installArtifact(lib);

    var tests = b.addTest(.{
        .root_source_file = b.path("src/janet.zig"),
        .optimize = optimize,
        .target = target,
    });

    tests.root_module.addImport("jzignet", c_header.createModule());
    tests.linkLibrary(lib);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const embed_janet_exe = b.addExecutable(.{
        .name = "embed_janet",
        .target = target,
        .root_source_file = b.path("examples/embed_janet.zig"),
    });

    embed_janet_exe.root_module.addImport("jzignet", mod);
    embed_janet_exe.linkLibrary(lib);

    b.installArtifact(embed_janet_exe);
    const run_embed_janet_exe = b.step("run-embed_janet", "Run embed_janet example");
    run_embed_janet_exe.dependOn(&b.addRunArtifact(embed_janet_exe).step);
}
