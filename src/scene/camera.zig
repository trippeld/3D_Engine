const std = @import("std");

const input = @import("../core/input.zig");
const math = @import("../core/math.zig");

pub const Camera = struct {
    position: math.Vec3 = .{ .x = 0.0, .y = 1.5, .z = 5.0 },
    yaw_deg: f32 = -90.0,
    pitch_deg: f32 = 0.0,
    move_speed: f32 = 5.0,
    mouse_sensitivity: f32 = 0.12,

    pub fn front(self: *const Camera) math.Vec3 {
        const yaw = std.math.degreesToRadians(self.yaw_deg);
        const pitch = std.math.degreesToRadians(self.pitch_deg);

        return math.Vec3.normalize(.{
            .x = @cos(yaw) * @cos(pitch),
            .y = @sin(pitch),
            .z = @sin(yaw) * @cos(pitch),
        });
    }

    pub fn right(self: *const Camera) math.Vec3 {
        return math.Vec3.normalize(
            math.Vec3.cross(self.front(), .{ .x = 0.0, .y = 1.0, .z = 0.0 }),
        );
    }

    pub fn process_mouse(self: *Camera, dx: f32, dy: f32) void {
        self.yaw_deg += dx * self.mouse_sensitivity;
        self.pitch_deg -= dy * self.mouse_sensitivity;

        self.pitch_deg = std.math.clamp(self.pitch_deg, -89.0, 89.0);
    }

    pub fn view_matrix(self: *const Camera) math.Mat4 {
        const eye = self.position;
        const center = math.Vec3.add(self.position, self.front());
        const up = math.Vec3.init(0.0, 1.0, 0.0);

        return math.Mat4.look_at(eye, center, up);
    }

    pub fn update(self: *Camera, state: input.State, dt: f32) void {
        const amount = self.move_speed * dt;

        if (state.move_forward) self.move_forward(amount);
        if (state.move_backward) self.move_backward(amount);
        if (state.move_left) self.move_left(amount);
        if (state.move_right) self.move_right(amount);
        if (state.move_up) self.move_up(amount);
        if (state.move_down) self.move_down(amount);
    }

    pub fn move_forward(self: *Camera, amount: f32) void {
        self.position = math.Vec3.add(self.position, math.Vec3.scale(self.front(), amount));
    }

    pub fn move_backward(self: *Camera, amount: f32) void {
        self.position = math.Vec3.sub(self.position, math.Vec3.scale(self.front(), amount));
    }

    pub fn move_right(self: *Camera, amount: f32) void {
        self.position = math.Vec3.add(self.position, math.Vec3.scale(self.right(), amount));
    }

    pub fn move_left(self: *Camera, amount: f32) void {
        self.position = math.Vec3.sub(self.position, math.Vec3.scale(self.right(), amount));
    }

    pub fn move_up(self: *Camera, amount: f32) void {
        self.position.y += amount;
    }

    pub fn move_down(self: *Camera, amount: f32) void {
        self.position.y -= amount;
    }
};
