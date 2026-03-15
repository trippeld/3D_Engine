pub const PushConstants = extern struct {
    view_proj: [16]f32,
    model: [16]f32,
    camera_pos: [4]f32,
    base_color: [4]f32,
    material_params: [4]f32,
    light_pos: [4]f32,
    light_color: [4]f32,
};

pub const vert_spv align(@alignOf(u32)) = @embedFile("scene.vert.spv").*;
pub const frag_spv align(@alignOf(u32)) = @embedFile("scene.frag.spv").*;
