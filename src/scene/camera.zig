const std = @import("std");

const input = @import("../core/input.zig");
const math = @import("../core/math.zig");

pub const Camera = struct {
    position: math.Vec3,
    yaw_deg: f32,
    pitch_deg: f32,
    move_speed: f32,
    mouse_sensitivity: f32,

    pub fn init(position: math.Vec3) Camera {
        return .{
            .position = position,
            .yaw_deg = -90.0,
            .pitch_deg = 0.0,
            .move_speed = 5.0,
            .mouse_sensitivity = 0.12,
        };
    }

    pub fn front(self: *const Camera) math.Vec3 {
        const yaw = std.math.degreesToRadians(self.yaw_deg);
        const pitch = std.math.degreesToRadians(self.pitch_deg);
        const cos_pitch = @cos(pitch);

        return math.Vec3.normalize(.{
            .x = @cos(yaw) * cos_pitch,
            .y = @sin(pitch),
            .z = @sin(yaw) * cos_pitch,
        });
    }

    pub fn right(self: *const Camera) math.Vec3 {
        const world_up = math.Vec3.init(0.0, 1.0, 0.0);
        return math.Vec3.normalize(math.Vec3.cross(self.front(), world_up));
    }

    pub fn up(self: *const Camera) math.Vec3 {
        return math.Vec3.normalize(math.Vec3.cross(self.right(), self.front()));
    }

    fn apply_mouse_delta(self: *Camera, delta_x: f32, delta_y: f32) void {
        self.yaw_deg += delta_x * self.mouse_sensitivity;
        self.pitch_deg -= delta_y * self.mouse_sensitivity;
        self.pitch_deg = std.math.clamp(self.pitch_deg, -89.0, 89.0);
    }

    pub fn process_mouse(self: *Camera, dx: f32, dy: f32) void {
        _ = self;
        _ = dx;
        _ = dy;
    }

    pub fn view_matrix(self: *const Camera) math.Mat4 {
        const eye = self.position;
        const center = math.Vec3.add(self.position, self.front());
        const world_up = math.Vec3.init(0.0, 1.0, 0.0);

        return math.Mat4.look_at(eye, center, world_up);
    }

    pub fn update(self: *Camera, state: input.State, dt: f32) void {
        self.apply_mouse_delta(state.mouse_delta_x, state.mouse_delta_y);

        var move_input = math.Vec3.init(0.0, 0.0, 0.0);

        if (state.move_forward) move_input.z += 1.0;
        if (state.move_backward) move_input.z -= 1.0;
        if (state.move_right) move_input.x += 1.0;
        if (state.move_left) move_input.x -= 1.0;
        if (state.move_up) move_input.y += 1.0;
        if (state.move_down) move_input.y -= 1.0;

        if (move_input.x == 0.0 and move_input.y == 0.0 and move_input.z == 0.0) {
            return;
        }

        var move_direction = math.Vec3.init(0.0, 0.0, 0.0);

        move_direction = math.Vec3.add(
            move_direction,
            math.Vec3.scale(self.front(), move_input.z),
        );
        move_direction = math.Vec3.add(
            move_direction,
            math.Vec3.scale(self.right(), move_input.x),
        );
        move_direction = math.Vec3.add(
            move_direction,
            math.Vec3.scale(math.Vec3.init(0.0, 1.0, 0.0), move_input.y),
        );

        const move_length_sq = math.Vec3.dot(move_direction, move_direction);
        if (move_length_sq > 0.0) {
            move_direction = math.Vec3.normalize(move_direction);
        }

        self.position = math.Vec3.add(
            self.position,
            math.Vec3.scale(move_direction, self.move_speed * dt),
        );
    }
};
