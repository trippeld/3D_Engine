const mesh = @import("../render/mesh.zig");
const material_file = @import("../render/material.zig");
const transform_file = @import("transform.zig");
const math = @import("../core/math.zig");

pub const Material = material_file.Material;
pub const StaticMesh = mesh.StaticMesh;
pub const Transform = transform_file.Transform;

pub const SceneObject = struct {
    parent_index: ?usize,
    local_transform: Transform,
};

pub const StaticMeshComponent = struct {
    object_index: usize,
    static_mesh: StaticMesh,
    material_index: usize,
};

pub const SceneLight = struct {
    position: math.Vec3,
    color: math.Vec3,
};

pub const SceneData = struct {
    objects: []const SceneObject,
    static_meshes: []const StaticMeshComponent,
    materials: []const Material,
    light: SceneLight,
};
