const math = @import("../core/math.zig");
const render_scene = @import("../render/render_scene.zig");
const scene_types = @import("scene_types.zig");

pub const max_scene_objects = 128;
pub const max_scene_materials = 128;

pub const SceneSubmitResult = struct {
    draw_objects: [max_scene_objects]render_scene.DrawObject,
    draw_object_count: usize,
    materials: [max_scene_materials]render_scene.Material,
    material_count: usize,
    light: render_scene.Light,

    pub fn render_scene_view(self: *const SceneSubmitResult) render_scene.RenderScene {
        return .{
            .objects = self.draw_objects[0..self.draw_object_count],
            .materials = self.materials[0..self.material_count],
            .light = self.light,
        };
    }
};

fn resolve_world_transform(
    objects: []const scene_types.SceneObject,
    index: usize,
) math.Mat4 {
    const object = objects[index];
    const local_model = object.local_transform.to_matrix();

    if (object.parent_index) |parent_index| {
        const parent_world = resolve_world_transform(objects, parent_index);
        return math.Mat4.mul(parent_world, local_model);
    }

    return local_model;
}

pub fn build_render_scene(scene: scene_types.SceneData) SceneSubmitResult {
    var result = SceneSubmitResult{
        .draw_objects = undefined,
        .draw_object_count = 0,
        .materials = undefined,
        .material_count = 0,
        .light = .{
            .position = scene.light.position,
            .color = scene.light.color,
        },
    };

    for (scene.materials, 0..) |material, i| {
        result.materials[i] = material;
    }
    result.material_count = scene.materials.len;

    for (scene.static_meshes, 0..) |mesh_component, i| {
        result.draw_objects[i] = .{
            .static_mesh = mesh_component.static_mesh,
            .model = resolve_world_transform(scene.objects, mesh_component.object_index),
            .material_index = mesh_component.material_index,
        };
    }
    result.draw_object_count = scene.static_meshes.len;

    return result;
}
