const math = @import("../core/math.zig");
const render_vk = @import("../render/vk/renderer.zig");

const DrawObject = render_vk.DrawObject;
const Material = render_vk.Material;
const Light = render_vk.Light;
const Scene = render_vk.Scene;

pub const BuiltScene = struct {
    light: Light,
    objects: [5]DrawObject,
};

const MainSceneConfig = struct {
    cube_positions: CubePositionConfig,
    left_cube_material: MaterialConfig,
    center_cube_material: MaterialConfig,
    right_cube_material: MaterialConfig,
    ground_material: MaterialConfig,
    ground: GroundConfig,
    light: LightConfig,
};

fn make_main_scene_config() MainSceneConfig {
    return .{
        .cube_positions = make_cube_position_config(cube_y),
        .left_cube_material = make_material_config(
            math.Vec3.init(1.0, 0.25, 0.25),
            0.0,
            4.0,
        ),
        .center_cube_material = make_material_config(
            math.Vec3.init(0.25, 1.0, 0.35),
            0.35,
            16.0,
        ),
        .right_cube_material = make_material_config(
            math.Vec3.init(0.35, 0.45, 1.0),
            1.2,
            128.0,
        ),
        .ground_material = make_material_config(
            math.Vec3.init(0.55, 0.55, 0.6),
            0.0,
            2.0,
        ),
        .ground = make_ground_config(),
        .light = make_light_config(),
    };
}

const MaterialConfig = struct {
    color: math.Vec3,
    specular_strength: f32,
    shininess: f32,
};

fn make_material_config(
    color: math.Vec3,
    specular_strength: f32,
    shininess: f32,
) MaterialConfig {
    return .{
        .color = color,
        .specular_strength = specular_strength,
        .shininess = shininess,
    };
}

const CubePositionConfig = struct {
    left: math.Vec3,
    center: math.Vec3,
    right: math.Vec3,
};

fn make_cube_position_config(y: f32) CubePositionConfig {
    return .{
        .left = math.Vec3.init(-2.0, y, 0.0),
        .center = math.Vec3.init(0.0, y, 0.0),
        .right = math.Vec3.init(2.0, y, 0.0),
    };
}

const LightConfig = struct {
    radius: f32,
    height: f32,
    speed: f32,
    color: math.Vec3,
    indicator_scale: math.Vec3,
};

fn make_light_config() LightConfig {
    return .{
        .radius = 4.0,
        .height = 3.0,
        .speed = 0.45,
        .color = math.Vec3.init(1.0, 0.9, 0.7),
        .indicator_scale = math.Vec3.init(0.2, 0.2, 0.2),
    };
}

const GroundConfig = struct {
    position: math.Vec3,
    scale: math.Vec3,
};

fn make_ground_config() GroundConfig {
    return .{
        .position = math.Vec3.init(0.0, -1.25, 0.0),
        .scale = math.Vec3.init(12.0, 0.1, 12.0),
    };
}

const cube_y: f32 = -0.15;

const main_scene_config = make_main_scene_config();

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
) [5]DrawObject {
    return .{
        make_light_indicator(light_model, light.color),
        make_cube_object(
            cube_models.left,
            main_scene_config.left_cube_material.color,
            main_scene_config.left_cube_material.specular_strength,
            main_scene_config.left_cube_material.shininess,
        ),
        make_cube_object(
            cube_models.center,
            main_scene_config.center_cube_material.color,
            main_scene_config.center_cube_material.specular_strength,
            main_scene_config.center_cube_material.shininess,
        ),
        make_cube_object(
            cube_models.right,
            main_scene_config.right_cube_material.color,
            main_scene_config.right_cube_material.specular_strength,
            main_scene_config.right_cube_material.shininess,
        ),
        make_ground_object(ground_model),
    };
}

fn build_main_scene(time: f32) BuiltScene {
    const cube_models = make_cube_models(time);

    const ground_model = make_ground_model();

    const light = make_main_light(time);
    const light_model = make_light_indicator_model(light.position);

    const objects = make_main_scene_objects(light, cube_models, ground_model, light_model);

    return .{
        .light = light,
        .objects = objects,
    };
}

pub fn build_scene(time: f32) BuiltScene {
    return build_main_scene(time);
}
