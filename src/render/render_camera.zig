const math = @import("../core/math.zig");

pub const RenderCamera = struct {
    view: math.Mat4,
    projection: math.Mat4,
    position: math.Vec3,
};
