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

    for (scene.objects, 0..) |object, i| {
        result.draw_objects[i] = .{
            .static_mesh = object.static_mesh,
            .model = object.model,
            .material_index = object.material_index,
        };
    }
    result.draw_object_count = scene.objects.len;

    return result;
}
