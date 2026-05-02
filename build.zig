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
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "jzignet",
        .linkage = .static,
        .root_module = mod,
    });

    var janet_flags: std.ArrayList([]const u8) = .empty;
    janet_flags.appendSlice(ally, &[_][]const u8{"-std=c99"}) catch unreachable;
    if (optimize != .Debug) {
        janet_flags.appendSlice(ally, &[_][]const u8{ "-O2", "-flto" }) catch unreachable;
    }
    if (no_nanbox) {
        janet_flags.appendSlice(ally, &[_][]const u8{"-DJANET_NO_NANBOX"}) catch unreachable;
    }
    lib.root_module.addIncludePath(b.path("c"));
    lib.root_module.addCSourceFile(.{ .file = b.path("c/janet.c"), .flags = janet_flags.items });
    b.installArtifact(lib);

    const jzignet_module = b.addModule("jzignet", .{
        .root_source_file = b.path("src/janet.zig"),
        .target = target,
        .optimize = optimize,
    });

    var tests = b.addTest(.{
        .root_module = jzignet_module,
    });

    tests.root_module.addImport("cjanet", c_header.createModule());
    tests.root_module.addImport("jzignet", mod);
    tests.root_module.linkLibrary(lib);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const embed_janet_module = b.addModule("embed_janet", .{
        .root_source_file = b.path("examples/embed_janet.zig"),
        .target = target,
        .optimize = optimize,
    });

    const embed_janet_exe = b.addExecutable(.{ .name = "embed_janet", .root_module = embed_janet_module });

    embed_janet_exe.root_module.addImport("jzignet", mod);
    embed_janet_exe.root_module.linkLibrary(lib);

    b.installArtifact(embed_janet_exe);
    const run_embed_janet_exe = b.step("run-embed_janet", "Run embed_janet example");
    run_embed_janet_exe.dependOn(&b.addRunArtifact(embed_janet_exe).step);
}
