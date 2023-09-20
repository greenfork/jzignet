const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    var ally = b.allocator;

    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const no_nanbox = b.option(bool, "no_nanbox", "Do not use nanbox implementation of Janet (default false)") orelse false;

    const c_header = b.addTranslateC(.{
        .source_file = .{ .path = "c/janet.h" },
        .optimize = optimize,
        .target = target,
    });
    const c_module = b.addModule("cjanet", .{
        .source_file = .{ .generated = &c_header.output_file },
    });

    const mod = b.addModule("jzignet", .{
        .source_file = .{ .path = "src/janet.zig" },
        .dependencies = &.{.{ .name = "cjanet", .module = c_module }},
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
    lib.addIncludePath(.{ .path = "c" });
    lib.addCSourceFile(.{ .file = .{ .path = "c/janet.c" }, .flags = janet_flags.items });
    b.installArtifact(lib);

    var tests = b.addTest(.{
        .root_source_file = .{ .path = "src/janet.zig" },
        .optimize = optimize,
        .target = target,
    });
    tests.addModule("cjanet", c_module);
    tests.linkLibrary(lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const ex1 = b.addExecutable(.{
        .name = "embed_janet",
        .root_source_file = .{ .path = "examples/embed_janet.zig" },
    });

    ex1.addModule("jzignet", mod);
    ex1.linkLibrary(lib);

    b.installArtifact(ex1);
    const run_ex1 = b.step("run-embed_janet", "Run embed_janet example");
    run_ex1.dependOn(&b.addRunArtifact(ex1).step);
}
