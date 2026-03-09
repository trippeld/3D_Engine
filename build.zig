const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    root_module.linkSystemLibrary("SDL3", .{});
    root_module.linkSystemLibrary("vulkan", .{});

    const exe = b.addExecutable(.{
        .name = "3d_engine",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run 3d_engine");
    run_step.dependOn(&run_cmd.step);
}
