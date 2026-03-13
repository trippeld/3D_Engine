const math = @import("../core/math.zig");

pub const MaterialConfig = struct {
    color: math.Vec3,
    specular_strength: f32,
    shininess: f32,
};

pub const CubePositionConfig = struct {
    left: math.Vec3,
    center: math.Vec3,
    right: math.Vec3,
};

pub const LightConfig = struct {
    radius: f32,
    height: f32,
    speed: f32,
    color: math.Vec3,
    indicator_scale: math.Vec3,
};

pub const GroundConfig = struct {
    position: math.Vec3,
    scale: math.Vec3,
};

pub const MainSceneConfig = struct {
    cube_positions: CubePositionConfig,
    left_cube_material: MaterialConfig,
    center_cube_material: MaterialConfig,
    right_cube_material: MaterialConfig,
    ground_material: MaterialConfig,
    ground: GroundConfig,
    light: LightConfig,
};

const cube_y: f32 = -0.15;

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

fn make_cube_position_config(y: f32) CubePositionConfig {
    return .{
        .left = math.Vec3.init(-2.0, y, 0.0),
        .center = math.Vec3.init(0.0, y, 0.0),
        .right = math.Vec3.init(2.0, y, 0.0),
    };
}

fn make_light_config() LightConfig {
    return .{
        .radius = 4.0,
        .height = 3.0,
        .speed = 0.45,
        .color = math.Vec3.init(1.0, 0.9, 0.7),
        .indicator_scale = math.Vec3.init(0.2, 0.2, 0.2),
    };
}

fn make_ground_config() GroundConfig {
    return .{
        .position = math.Vec3.init(0.0, -1.25, 0.0),
        .scale = math.Vec3.init(12.0, 0.1, 12.0),
    };
}

pub fn make_main_scene_config() MainSceneConfig {
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
