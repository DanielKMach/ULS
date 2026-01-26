const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install_step = b.getInstallStep();
    const run_step = b.step("run", "Run the app");
    const test_step = b.step("test", "Run tests");

    const usrl = b.dependency("usrl", .{
        .optimize = optimize,
        .target = target,
    });

    const mod = b.addModule("ulsp", .{
        .root_source_file = b.path("server/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "usrl", .module = usrl.module("usrl") },
        },
    });

    // Installing
    const exe = b.addExecutable(.{
        .name = "ulsp",
        .root_module = mod,
    });

    const install_exe = b.addInstallArtifact(exe, .{});
    install_step.dependOn(&install_exe.step);

    // Running
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(install_step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    run_step.dependOn(&run_cmd.step);

    // Testing
    const tests = b.addTest(.{
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
