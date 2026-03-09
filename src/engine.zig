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
        print_accum += dt;

        camera.update(input, dt);

        if (print_accum >= 0.5) {
            print_accum = 0.0;

            const front = camera.front();
            const to_target = math.Vec3.sub(target_pos, camera.position);
            const distance = math.Vec3.length(to_target);

            const facing = if (distance <= 0.00001)
                1.0
            else
                math.Vec3.dot(front, math.Vec3.normalize(to_target));

            std.log.info(
                "cam pos=({d:.2}, {d:.2}, {d:.2}) target_dist={d:.2} facing={d:.2} swapchain={d} extent={d}x{d}",
                .{
                    camera.position.x,
                    camera.position.y,
                    camera.position.z,
                    distance,
                    facing,
                    renderer.swapchain_images.len,
                    renderer.swapchain_extent.width,
                    renderer.swapchain_extent.height,
                },
            );
        }

        platform.delay_ms(1);
    }
}
