const math = @import("../core/math.zig");
const scene_config = @import("scene_config.zig");
const scene_types = @import("scene_types.zig");
const material_file = @import("../render/material.zig");
const transform_file = @import("transform.zig");

const SceneObject = scene_types.SceneObject;
const StaticMeshComponent = scene_types.StaticMeshComponent;
const SceneLight = scene_types.SceneLight;
const SceneData = scene_types.SceneData;
const Material = material_file.Material;
const Transform = transform_file.Transform;

const main_scene_config = scene_config.make_main_scene_config();

const max_scene_objects = 16;
const max_scene_static_meshes = 16;
const max_scene_materials = 16;

const MainMaterialIndex = enum(usize) {
    light_indicator = 0,
    left_cube = 1,
    center_cube = 2,
    right_cube = 3,
    ground = 4,
};

const MainObjectIndex = enum(usize) {
    light_indicator = 0,
    left_cube = 1,
    center_cube = 2,
    right_cube = 3,
    ground = 4,
};

pub const SceneBuildResult = struct {
    light: SceneLight,
    objects: [max_scene_objects]SceneObject,
    object_count: usize,
    static_meshes: [max_scene_static_meshes]StaticMeshComponent,
    static_mesh_count: usize,
    materials: [max_scene_materials]Material,
    material_count: usize,

    pub fn scene_data(self: *const SceneBuildResult) SceneData {
        return .{
            .objects = self.objects[0..self.object_count],
            .static_meshes = self.static_meshes[0..self.static_mesh_count],
            .materials = self.materials[0..self.material_count],
            .light = self.light,
        };
    }
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

fn make_scene_object(
    parent_index: ?usize,
    local_transform: Transform,
) SceneObject {
    return .{
        .parent_index = parent_index,
        .local_transform = local_transform,
    };
}

fn make_static_mesh_component(
    object_index: usize,
    static_mesh: scene_types.StaticMesh,
    material_index: usize,
) StaticMeshComponent {
    return .{
        .object_index = object_index,
        .static_mesh = static_mesh,
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

const CubeTransforms = struct {
    left: Transform,
    center: Transform,
    right: Transform,
};

fn make_cube_transforms(time: f32) CubeTransforms {
    return .{
        .left = .{
            .position = main_scene_config.cube_positions.left,
            .rotation_y = time,
            .scale = math.Vec3.init(1.0, 1.0, 1.0),
        },
        .center = .{
            .position = main_scene_config.cube_positions.center,
            .rotation_y = time,
            .scale = math.Vec3.init(1.0, 1.0, 1.0),
        },
        .right = .{
            .position = main_scene_config.cube_positions.right,
            .rotation_y = time,
            .scale = math.Vec3.init(1.0, 1.0, 1.0),
        },
    };
}

fn make_ground_transform() Transform {
    return .{
        .position = main_scene_config.ground.position,
        .rotation_y = 0.0,
        .scale = main_scene_config.ground.scale,
    };
}

fn make_light_indicator_transform(light_position: math.Vec3) Transform {
    return .{
        .position = light_position,
        .rotation_y = 0.0,
        .scale = main_scene_config.light.indicator_scale,
    };
}

fn make_main_light(time: f32) SceneLight {
    return .{
        .position = make_light_position(time),
        .color = main_scene_config.light.color,
    };
}

fn make_main_scene_objects(
    cube_transforms: CubeTransforms,
    ground_transform: Transform,
    light_transform: Transform,
) struct {
    objects: [max_scene_objects]SceneObject,
    object_count: usize,
} {
    var objects: [max_scene_objects]SceneObject = undefined;
    var object_count: usize = 0;

    objects[object_count] = make_scene_object(null, light_transform);
    object_count += 1;

    objects[object_count] = make_scene_object(null, cube_transforms.left);
    object_count += 1;

    objects[object_count] = make_scene_object(null, cube_transforms.center);
    object_count += 1;

    objects[object_count] = make_scene_object(null, cube_transforms.right);
    object_count += 1;

    objects[object_count] = make_scene_object(null, ground_transform);
    object_count += 1;

    return .{
        .objects = objects,
        .object_count = object_count,
    };
}

fn make_main_scene_static_meshes() struct {
    static_meshes: [max_scene_static_meshes]StaticMeshComponent,
    static_mesh_count: usize,
} {
    var static_meshes: [max_scene_static_meshes]StaticMeshComponent = undefined;
    var static_mesh_count: usize = 0;

    static_meshes[static_mesh_count] = make_static_mesh_component(
        @intFromEnum(MainObjectIndex.light_indicator),
        .cube,
        @intFromEnum(MainMaterialIndex.light_indicator),
    );
    static_mesh_count += 1;

    static_meshes[static_mesh_count] = make_static_mesh_component(
        @intFromEnum(MainObjectIndex.left_cube),
        .cube,
        @intFromEnum(MainMaterialIndex.left_cube),
    );
    static_mesh_count += 1;

    static_meshes[static_mesh_count] = make_static_mesh_component(
        @intFromEnum(MainObjectIndex.center_cube),
        .cube,
        @intFromEnum(MainMaterialIndex.center_cube),
    );
    static_mesh_count += 1;

    static_meshes[static_mesh_count] = make_static_mesh_component(
        @intFromEnum(MainObjectIndex.right_cube),
        .cube,
        @intFromEnum(MainMaterialIndex.right_cube),
    );
    static_mesh_count += 1;

    static_meshes[static_mesh_count] = make_static_mesh_component(
        @intFromEnum(MainObjectIndex.ground),
        .plane,
        @intFromEnum(MainMaterialIndex.ground),
    );
    static_mesh_count += 1;

    return .{
        .static_meshes = static_meshes,
        .static_mesh_count = static_mesh_count,
    };
}

fn make_main_scene(time: f32) SceneBuildResult {
    const cube_transforms = make_cube_transforms(time);
    const ground_transform = make_ground_transform();

    const light = make_main_light(time);
    const light_transform = make_light_indicator_transform(light.position);

    const scene_materials = make_main_scene_materials(light.color);
    const scene_objects = make_main_scene_objects(
        cube_transforms,
        ground_transform,
        light_transform,
    );
    const scene_static_meshes = make_main_scene_static_meshes();

    return .{
        .light = light,
        .objects = scene_objects.objects,
        .object_count = scene_objects.object_count,
        .static_meshes = scene_static_meshes.static_meshes,
        .static_mesh_count = scene_static_meshes.static_mesh_count,
        .materials = scene_materials.materials,
        .material_count = scene_materials.material_count,
    };
}

pub fn make_scene(time: f32) SceneBuildResult {
    return make_main_scene(time);
}
