const std = @import("std");

const math = @import("core/math.zig");
const platform = @import("platform/sdl.zig");
const Camera = @import("scene/camera.zig").Camera;
const Renderer = @import("render/vk/renderer.zig").Renderer;

pub fn run() !void {
    try platform.init();
    defer platform.quit();

    const window = try platform.create_window("3D Engine", 1280, 720);
    defer platform.destroy_window(window);

    try platform.set_relative_mouse_mode(window, true);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var renderer = try Renderer.init(allocator, window);
    defer renderer.deinit();

    var camera = Camera{};
    const target_pos = math.Vec3.init(0.0, 0.0, 0.0);

    var running = true;
    var timer = platform.Timer.start();
    var print_accum: f32 = 0.0;

    var total_time: f32 = 0.0;

    while (running) {
        while (platform.poll_event()) |event| {
            switch (event) {
                .quit => running = false,
                .key_down => |key| switch (key) {
                    .escape => running = false,
                },
                .mouse_motion => |motion| {
                    camera.process_mouse(motion.dx, motion.dy);
                },
                .none => {},
            }
        }

        const input = platform.read_input_state();
        const dt = timer.tick();
        total_time += dt;
        print_accum += dt;

        camera.update(input, dt);
        const aspect = @as(f32, @floatFromInt(renderer.swapchain_extent.width)) /
            @as(f32, @floatFromInt(renderer.swapchain_extent.height));

        var proj = math.Mat4.perspective(
            std.math.degreesToRadians(75.0),
            aspect,
            0.1,
            200.0,
        );

        // Vulkan clip-space has inverted Y compared to the usual GL-style projection.
        proj.data[5] *= -1.0;

        const view = camera.view_matrix();
        const view_proj = math.Mat4.mul(proj, view);

        const model = math.Mat4.mul(
            math.Mat4.translate(math.Vec3.init(0.0, 0.0, -3.0)),
            math.Mat4.rotate_y(total_time),
        );

        try renderer.draw_frame(.{
            .view_proj = view_proj,
            .model = model,
        });

        if (print_accum >= 1.0) {
            print_accum = 0.0;

            const front = camera.front();
            const to_target = math.Vec3.sub(target_pos, camera.position);
            const distance = math.Vec3.length(to_target);

            const facing = if (distance <= 0.00001)
                1.0
            else
                math.Vec3.dot(front, math.Vec3.normalize(to_target));

            std.log.info(
                "cam pos=({d:.2}, {d:.2}, {d:.2}) target_dist={d:.2} facing={d:.2}",
                .{
                    camera.position.x,
                    camera.position.y,
                    camera.position.z,
                    distance,
                    facing,
                },
            );
        }
    }
}
