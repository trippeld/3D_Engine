const math = @import("../core/math.zig");

pub const Transform = struct {
    position: math.Vec3,
    rotation_y: f32,
    scale: math.Vec3,

    pub fn identity() Transform {
        return .{
            .position = math.Vec3.init(0.0, 0.0, 0.0),
            .rotation_y = 0.0,
            .scale = math.Vec3.init(1.0, 1.0, 1.0),
        };
    }

    pub fn to_matrix(self: Transform) math.Mat4 {
        const translation = math.Mat4.translate(self.position);
        const rotation = math.Mat4.rotate_y(self.rotation_y);
        const scale = math.Mat4.scale(self.scale);

        return math.Mat4.mul(math.Mat4.mul(translation, rotation), scale);
    }
};
