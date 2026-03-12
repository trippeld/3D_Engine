const std = @import("std");

const math = @import("core/math.zig");
const platform = @import("platform/sdl.zig");
const Camera = @import("scene/camera.zig").Camera;
const render_vk = @import("render/vk/renderer.zig");
const Renderer = render_vk.Renderer;
const DrawObject = render_vk.DrawObject;

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

        const time = timer.total_time();

        const cube_y: f32 = -0.15;

        const left_translation = math.Mat4.translate(math.Vec3.init(-2.0, cube_y, 0.0));
        const center_translation = math.Mat4.translate(math.Vec3.init(0.0, cube_y, 0.0));
        const right_translation = math.Mat4.translate(math.Vec3.init(2.0, cube_y, 0.0));

        const rotation = math.Mat4.rotate_y(time);

        const left_model = math.Mat4.mul(left_translation, rotation);
        const center_model = math.Mat4.mul(center_translation, rotation);
        const right_model = math.Mat4.mul(right_translation, rotation);

        const ground_translation = math.Mat4.translate(math.Vec3.init(0.0, -1.25, 0.0));
        const ground_scale = math.Mat4.scale(math.Vec3.init(12.0, 0.1, 12.0));
        const ground_model = math.Mat4.mul(ground_translation, ground_scale);

        const light_radius: f32 = 4.0;
        const light_height: f32 = 3.0;
        const light_speed: f32 = 0.45;

        const light_pos = math.Vec3.init(
            @cos(time * light_speed) * light_radius,
            light_height,
            @sin(time * light_speed) * light_radius,
        );

        const light_color = math.Vec3.init(1.0, 0.9, 0.7);

        const light_translation = math.Mat4.translate(light_pos);
        const light_scale = math.Mat4.scale(math.Vec3.init(0.2, 0.2, 0.2));
        const light_model = math.Mat4.mul(light_translation, light_scale);

        const objects = [_]DrawObject{
            .{
                .model = left_model,
                .color = math.Vec3.init(1.0, 0.25, 0.25),
                .specular_strength = 0.0,
                .shininess = 4.0,
                .unlit = 0.0,
            },
            .{
                .model = center_model,
                .color = math.Vec3.init(0.25, 1.0, 0.35),
                .specular_strength = 0.35,
                .shininess = 16.0,
                .unlit = 0.0,
            },
            .{
                .model = right_model,
                .color = math.Vec3.init(0.35, 0.45, 1.0),
                .specular_strength = 1.2,
                .shininess = 128.0,
                .unlit = 0.0,
            },
            .{
                .model = ground_model,
                .color = math.Vec3.init(0.55, 0.55, 0.6),
                .specular_strength = 0.0,
                .shininess = 2.0,
                .unlit = 0.0,
            },
            .{
                .model = light_model,
                .color = light_color,
                .specular_strength = 0.0,
                .shininess = 1.0,
                .unlit = 1.0,
            },
        };

        try renderer.draw_frame(.{
            .view_proj = view_proj,
            .camera_pos = camera.position,
            .light_pos = light_pos,
            .light_color = light_color,
            .objects = objects[0..],
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
