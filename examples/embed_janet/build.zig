const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    // Add the library to the compilation unit but specify correct paths.
    var ally = b.allocator;
    var janet_flags = std.ArrayList([]const u8).init(ally);
    janet_flags.appendSlice(&[_][]const u8{"-std=c99"}) catch unreachable;
    if (mode != .Debug) {
        janet_flags.appendSlice(&[_][]const u8{ "-O2", "-flto" }) catch unreachable;
    }
    const janet = b.addStaticLibrary("janet", null);
    janet.addCSourceFile("../../c/janet.c", janet_flags.items);
    janet.addIncludeDir("../../c");
    janet.linkLibC();

    const exe = b.addExecutable("embed_janet", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    // Add the library to your exe file.
    exe.linkLibC();
    exe.linkLibrary(janet);
    exe.addPackagePath("jzignet", "../../src/janet.zig");
    exe.addIncludeDir("../../c");

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
