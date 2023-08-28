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
    _ = mod;

    const janet_lib = b.addStaticLibrary(.{
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
    janet_lib.linkLibC();
    janet_lib.addIncludePath(.{ .path = "c" });
    janet_lib.addCSourceFile(.{ .file = .{ .path = "c/janet.c" }, .flags = janet_flags.items });
    b.installArtifact(janet_lib);

    var tests = b.addTest(.{
        .root_source_file = .{ .path = "src/janet.zig" },
        .optimize = optimize,
        .target = target,
    });
    tests.addModule("cjanet", c_module);
    tests.linkLibrary(janet_lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
