const math = @import("../core/math.zig");
const render_vk = @import("../render/vk/renderer.zig");
const scene_config = @import("scene_config.zig");

const DrawObject = render_vk.DrawObject;
const Material = render_vk.Material;
const Light = render_vk.Light;
const Scene = render_vk.Scene;
const main_scene_config = scene_config.make_main_scene_config();

const max_scene_objects = 16;

pub const SceneBuildResult = struct {
    light: Light,
    objects: [max_scene_objects]DrawObject,
    object_count: usize,
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
        .unlit = 0.0,
    };
}

fn unlit_material(base_color: math.Vec3) Material {
    return .{
        .base_color = base_color,
        .specular_strength = 0.0,
        .shininess = 1.0,
        .unlit = 1.0,
    };
}

fn make_cube_object(
    model: math.Mat4,
    base_color: math.Vec3,
    specular_strength: f32,
    shininess: f32,
) DrawObject {
    return .{
        .model = model,
        .material = lit_material(base_color, specular_strength, shininess),
    };
}

fn make_ground_object(model: math.Mat4) DrawObject {
    return .{
        .model = model,
        .material = lit_material(
            main_scene_config.ground_material.color,
            main_scene_config.ground_material.specular_strength,
            main_scene_config.ground_material.shininess,
        ),
    };
}

fn make_light_indicator(model: math.Mat4, color: math.Vec3) DrawObject {
    return .{
        .model = model,
        .material = unlit_material(color),
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
    light: Light,
    cube_models: CubeModels,
    ground_model: math.Mat4,
    light_model: math.Mat4,
) struct {
    objects: [max_scene_objects]DrawObject,
    object_count: usize,
} {
    var objects: [max_scene_objects]DrawObject = undefined;
    var object_count: usize = 0;

    objects[object_count] = make_light_indicator(light_model, light.color);
    object_count += 1;

    objects[object_count] = make_cube_object(
        cube_models.left,
        main_scene_config.left_cube_material.color,
        main_scene_config.left_cube_material.specular_strength,
        main_scene_config.left_cube_material.shininess,
    );
    object_count += 1;

    objects[object_count] = make_cube_object(
        cube_models.center,
        main_scene_config.center_cube_material.color,
        main_scene_config.center_cube_material.specular_strength,
        main_scene_config.center_cube_material.shininess,
    );
    object_count += 1;

    objects[object_count] = make_cube_object(
        cube_models.right,
        main_scene_config.right_cube_material.color,
        main_scene_config.right_cube_material.specular_strength,
        main_scene_config.right_cube_material.shininess,
    );
    object_count += 1;

    objects[object_count] = make_ground_object(ground_model);
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

    const scene_objects = make_main_scene_objects(light, cube_models, ground_model, light_model);

    return .{
        .light = light,
        .objects = scene_objects.objects,
        .object_count = scene_objects.object_count,
    };
}

pub fn make_scene(time: f32) SceneBuildResult {
    return make_main_scene(time);
}
