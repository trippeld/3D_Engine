const math = @import("../core/math.zig");
const mesh = @import("mesh.zig");

pub const Material = struct {
    base_color: math.Vec3,
    specular_strength: f32,
    shininess: f32,
    emissive_color: math.Vec3,
    emissive_strength: f32,
    unlit: f32,
};

pub const DrawObject = struct {
    static_mesh: mesh.StaticMesh,
    model: math.Mat4,
    material: Material,
};

pub const Light = struct {
    position: math.Vec3,
    color: math.Vec3,
};

pub const RenderScene = struct {
    objects: []const DrawObject,
    light: Light,
};
