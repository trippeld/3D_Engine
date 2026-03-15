const math = @import("../core/math.zig");

pub const Material = struct {
    base_color: math.Vec3,
    specular_strength: f32,
    shininess: f32,
    emissive_color: math.Vec3,
    emissive_strength: f32,
    unlit: f32,
};
