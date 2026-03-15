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

    const compile_scene_vert = b.addSystemCommand(&.{
        "glslc",
        "src/render/vk/shaders/scene.vert",
        "-o",
        "src/render/vk/shaders/scene.vert.spv",
    });

    const compile_scene_frag = b.addSystemCommand(&.{
        "glslc",
        "src/render/vk/shaders/scene.frag",
        "-o",
        "src/render/vk/shaders/scene.frag.spv",
    });

    exe.step.dependOn(&compile_scene_vert.step);
    exe.step.dependOn(&compile_scene_frag.step);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run 3d_engine");
    run_step.dependOn(&run_cmd.step);
}
