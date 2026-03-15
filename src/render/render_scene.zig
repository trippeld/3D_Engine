const math = @import("../core/math.zig");
const mesh = @import("mesh.zig");
const material_file = @import("material.zig");

pub const Material = material_file.Material;

pub const DrawObject = struct {
    static_mesh: mesh.StaticMesh,
    model: math.Mat4,
    material_index: usize,
};

pub const Light = struct {
    position: math.Vec3,
    color: math.Vec3,
};

pub const RenderScene = struct {
    objects: []const DrawObject,
    materials: []const Material,
    light: Light,
};
