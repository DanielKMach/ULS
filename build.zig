const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install_step = b.getInstallStep();
    const test_step = b.step("test", "Run tests");

    const all = b.option(bool, "all", "Compile to all targets with their apropriate names") orelse false;

    const targets = if (all) &.{
        b.resolveTargetQuery(.{ .os_tag = .windows, .cpu_arch = .x86_64 }),
        b.resolveTargetQuery(.{ .os_tag = .macos, .cpu_arch = .x86_64 }),
        b.resolveTargetQuery(.{ .os_tag = .linux, .cpu_arch = .x86_64 }),
    } else &.{target};

    for (targets) |t| {
        const mod = uls(b, t, optimize);

        const name = switch (t.result.os.tag) {
            .windows => "uls-windows",
            .macos => "uls-macos",
            .linux => "uls-linux",
            else => unreachable,
        };

        // Installing
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = mod,
        });

        const install_exe = b.addInstallArtifact(exe, .{});
        install_step.dependOn(&install_exe.step);

        // Testing
        const tests = b.addTest(.{
            .root_module = mod,
        });

        const run_tests = b.addRunArtifact(tests);
        test_step.dependOn(&run_tests.step);
    }
}

fn uls(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const usrl = b.dependency("usrl", .{
        .optimize = optimize,
        .target = target,
    });

    const lsp = b.dependency("lsp_kit", .{
        .optimize = optimize,
        .target = target,
    });

    return b.addModule("uls", .{
        .root_source_file = b.path("server/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "usrl", .module = usrl.module("usrl") },
            .{ .name = "lsp", .module = lsp.module("lsp") },
        },
    });
}
