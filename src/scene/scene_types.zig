const math = @import("../core/math.zig");
const mesh = @import("../render/mesh.zig");
const material_file = @import("../render/material.zig");

pub const Material = material_file.Material;
pub const StaticMesh = mesh.StaticMesh;

pub const SceneObject = struct {
    static_mesh: StaticMesh,
    model: math.Mat4,
    material_index: usize,
};

pub const SceneLight = struct {
    position: math.Vec3,
    color: math.Vec3,
};

pub const SceneData = struct {
    objects: []const SceneObject,
    materials: []const Material,
    light: SceneLight,
};
