const math = @import("../core/math.zig");
const scene_config = @import("scene_config.zig");
const render_scene = @import("../render/render_scene.zig");
const material_file = @import("../render/material.zig");
const mesh = @import("../render/mesh.zig");

const DrawObject = render_scene.DrawObject;
const Material = material_file.Material;
const Light = render_scene.Light;
const StaticMesh = mesh.StaticMesh;

const main_scene_config = scene_config.make_main_scene_config();

const max_scene_objects = 16;
const max_scene_materials = 16;

const MainMaterialIndex = enum(usize) {
    light_indicator = 0,
    left_cube = 1,
    center_cube = 2,
    right_cube = 3,
    ground = 4,
};

pub const SceneBuildResult = struct {
    light: Light,
    objects: [max_scene_objects]DrawObject,
    object_count: usize,
    materials: [max_scene_materials]Material,
    material_count: usize,
};

fn lit_material(
    base_color: math.Vec3,
    specular_strength: f32,
    shininess: f32,
) Material {
    return .{
        .base_color = base_color,
        .specular_strength = specular_strength,
        .shininess = shininess,
        .emissive_color = math.Vec3.init(0.0, 0.0, 0.0),
        .emissive_strength = 0.0,
        .unlit = 0.0,
    };
}

fn unlit_material(color: math.Vec3) Material {
    return .{
        .base_color = color,
        .specular_strength = 0.0,
        .shininess = 1.0,
        .emissive_color = color,
        .emissive_strength = 1.0,
        .unlit = 1.0,
    };
}

fn make_cube_object(
    model: math.Mat4,
    material_index: usize,
) DrawObject {
    return .{
        .static_mesh = .cube,
        .model = model,
        .material_index = material_index,
    };
}

fn make_ground_object(model: math.Mat4, material_index: usize) DrawObject {
    return .{
        .static_mesh = .plane,
        .model = model,
        .material_index = material_index,
    };
}

fn make_light_indicator(model: math.Mat4, material_index: usize) DrawObject {
    return .{
        .static_mesh = .cube,
        .model = model,
        .material_index = material_index,
    };
}

fn make_main_scene_materials(light_color: math.Vec3) struct {
    materials: [max_scene_materials]Material,
    material_count: usize,
} {
    var materials: [max_scene_materials]Material = undefined;
    var material_count: usize = 0;

    materials[material_count] = unlit_material(light_color);
    material_count += 1;

    materials[material_count] = lit_material(
        main_scene_config.left_cube_material.color,
        main_scene_config.left_cube_material.specular_strength,
        main_scene_config.left_cube_material.shininess,
    );
    material_count += 1;

    materials[material_count] = lit_material(
        main_scene_config.center_cube_material.color,
        main_scene_config.center_cube_material.specular_strength,
        main_scene_config.center_cube_material.shininess,
    );
    material_count += 1;

    materials[material_count] = lit_material(
        main_scene_config.right_cube_material.color,
        main_scene_config.right_cube_material.specular_strength,
        main_scene_config.right_cube_material.shininess,
    );
    material_count += 1;

    materials[material_count] = lit_material(
        main_scene_config.ground_material.color,
        main_scene_config.ground_material.specular_strength,
        main_scene_config.ground_material.shininess,
    );
    material_count += 1;

    return .{
        .materials = materials,
        .material_count = material_count,
    };
}

fn make_light_position(time: f32) math.Vec3 {
    return math.Vec3.init(
        @cos(time * main_scene_config.light.speed) * main_scene_config.light.radius,
        main_scene_config.light.height,
        @sin(time * main_scene_config.light.speed) * main_scene_config.light.radius,
    );
}

const CubeModels = struct {
    left: math.Mat4,
    center: math.Mat4,
    right: math.Mat4,
};

fn make_cube_models(time: f32) CubeModels {
    const left_translation = math.Mat4.translate(main_scene_config.cube_positions.left);
    const center_translation = math.Mat4.translate(main_scene_config.cube_positions.center);
    const right_translation = math.Mat4.translate(main_scene_config.cube_positions.right);

    const rotation = math.Mat4.rotate_y(time);

    return .{
        .left = math.Mat4.mul(left_translation, rotation),
        .center = math.Mat4.mul(center_translation, rotation),
        .right = math.Mat4.mul(right_translation, rotation),
    };
}

fn make_ground_model() math.Mat4 {
    const ground_translation = math.Mat4.translate(main_scene_config.ground.position);
    const ground_scale_matrix = math.Mat4.scale(main_scene_config.ground.scale);
    return math.Mat4.mul(ground_translation, ground_scale_matrix);
}

fn make_light_indicator_model(light_position: math.Vec3) math.Mat4 {
    const light_translation = math.Mat4.translate(light_position);
    const light_scale_matrix = math.Mat4.scale(main_scene_config.light.indicator_scale);
    return math.Mat4.mul(light_translation, light_scale_matrix);
}

fn make_main_light(time: f32) Light {
    return .{
        .position = make_light_position(time),
        .color = main_scene_config.light.color,
    };
}

fn make_main_scene_objects(
    cube_models: CubeModels,
    ground_model: math.Mat4,
    light_model: math.Mat4,
) struct {
    objects: [max_scene_objects]DrawObject,
    object_count: usize,
} {
    var objects: [max_scene_objects]DrawObject = undefined;
    var object_count: usize = 0;

    objects[object_count] = make_light_indicator(
        light_model,
        @intFromEnum(MainMaterialIndex.light_indicator),
    );
    object_count += 1;

    objects[object_count] = make_cube_object(
        cube_models.left,
        @intFromEnum(MainMaterialIndex.left_cube),
    );
    object_count += 1;

    objects[object_count] = make_cube_object(
        cube_models.center,
        @intFromEnum(MainMaterialIndex.center_cube),
    );
    object_count += 1;

    objects[object_count] = make_cube_object(
        cube_models.right,
        @intFromEnum(MainMaterialIndex.right_cube),
    );
    object_count += 1;

    objects[object_count] = make_ground_object(
        ground_model,
        @intFromEnum(MainMaterialIndex.ground),
    );
    object_count += 1;

    return .{
        .objects = objects,
        .object_count = object_count,
    };
}

fn make_main_scene(time: f32) SceneBuildResult {
    const cube_models = make_cube_models(time);
    const ground_model = make_ground_model();

    const light = make_main_light(time);
    const light_model = make_light_indicator_model(light.position);

    const scene_materials = make_main_scene_materials(light.color);
    const scene_objects = make_main_scene_objects(
        cube_models,
        ground_model,
        light_model,
    );

    return .{
        .light = light,
        .objects = scene_objects.objects,
        .object_count = scene_objects.object_count,
        .materials = scene_materials.materials,
        .material_count = scene_materials.material_count,
    };
}

pub fn make_scene(time: f32) SceneBuildResult {
    return make_main_scene(time);
}
