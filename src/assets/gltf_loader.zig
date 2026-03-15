const std = @import("std");
const mesh_data = @import("mesh_data.zig");

pub const LoadError = error{
    InvalidGltf,
    UnsupportedGltf,
    MissingBuffer,
    MissingMesh,
    MissingPrimitive,
    MissingAttribute,
};

const BufferInfo = struct {
    uri: []const u8,
    byte_length: usize,
};

const BufferViewInfo = struct {
    buffer_index: usize,
    byte_offset: usize,
    byte_length: usize,
};

const AccessorInfo = struct {
    buffer_view_index: usize,
    byte_offset: usize,
    component_type: u32,
    count: usize,
    accessor_type: []const u8,
};

const PrimitiveInfo = struct {
    position_accessor_index: usize,
    normal_accessor_index: usize,
    index_accessor_index: usize,
};

fn get_object(value: std.json.Value) LoadError!std.json.ObjectMap {
    return switch (value) {
        .object => |object| object,
        else => LoadError.InvalidGltf,
    };
}

fn get_array(value: std.json.Value) LoadError!std.json.Array {
    return switch (value) {
        .array => |array| array,
        else => LoadError.InvalidGltf,
    };
}

fn get_string(object: std.json.ObjectMap, key: []const u8) LoadError![]const u8 {
    const value = object.get(key) orelse return LoadError.InvalidGltf;
    return switch (value) {
        .string => |string| string,
        else => LoadError.InvalidGltf,
    };
}

fn get_integer(object: std.json.ObjectMap, key: []const u8) LoadError!usize {
    const value = object.get(key) orelse return LoadError.InvalidGltf;
    return switch (value) {
        .integer => |integer| @intCast(integer),
        else => LoadError.InvalidGltf,
    };
}

fn get_optional_integer(object: std.json.ObjectMap, key: []const u8, default_value: usize) LoadError!usize {
    const value = object.get(key) orelse return default_value;
    return switch (value) {
        .integer => |integer| @intCast(integer),
        else => LoadError.InvalidGltf,
    };
}

fn parse_buffer_info(value: std.json.Value) LoadError!BufferInfo {
    const object = try get_object(value);

    return .{
        .uri = try get_string(object, "uri"),
        .byte_length = try get_integer(object, "byteLength"),
    };
}

fn parse_buffer_view_info(value: std.json.Value) LoadError!BufferViewInfo {
    const object = try get_object(value);

    return .{
        .buffer_index = try get_integer(object, "buffer"),
        .byte_offset = try get_optional_integer(object, "byteOffset", 0),
        .byte_length = try get_integer(object, "byteLength"),
    };
}

fn parse_accessor_info(value: std.json.Value) LoadError!AccessorInfo {
    const object = try get_object(value);

    return .{
        .buffer_view_index = try get_integer(object, "bufferView"),
        .byte_offset = try get_optional_integer(object, "byteOffset", 0),
        .component_type = @intCast(try get_integer(object, "componentType")),
        .count = try get_integer(object, "count"),
        .accessor_type = try get_string(object, "type"),
    };
}

fn parse_first_primitive_info(root: std.json.Value) LoadError!PrimitiveInfo {
    const root_object = try get_object(root);
    const meshes_value = root_object.get("meshes") orelse return LoadError.MissingMesh;
    const meshes = try get_array(meshes_value);

    if (meshes.items.len == 0) {
        return LoadError.MissingMesh;
    }

    const first_mesh = try get_object(meshes.items[0]);
    const primitives_value = first_mesh.get("primitives") orelse return LoadError.MissingPrimitive;
    const primitives = try get_array(primitives_value);

    if (primitives.items.len == 0) {
        return LoadError.MissingPrimitive;
    }

    const primitive = try get_object(primitives.items[0]);
    const attributes_value = primitive.get("attributes") orelse return LoadError.MissingAttribute;
    const attributes = try get_object(attributes_value);

    return .{
        .position_accessor_index = try value_to_index(
            attributes.get("POSITION") orelse return LoadError.MissingAttribute,
        ),
        .normal_accessor_index = try value_to_index(
            attributes.get("NORMAL") orelse return LoadError.MissingAttribute,
        ),
        .index_accessor_index = try value_to_index(
            primitive.get("indices") orelse return LoadError.MissingAttribute,
        ),
    };
}

fn value_to_index(value: std.json.Value) LoadError!usize {
    return switch (value) {
        .integer => |integer| @intCast(integer),
        else => LoadError.InvalidGltf,
    };
}

pub fn load_first_mesh(
    allocator: std.mem.Allocator,
    gltf_path: []const u8,
) !mesh_data.MeshData {
    const cwd = std.fs.cwd();

    const json_bytes = try cwd.readFileAlloc(
        allocator,
        gltf_path,
        16 * 1024 * 1024,
    );
    defer allocator.free(json_bytes);

    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_bytes,
        .{},
    );
    defer parsed.deinit();

    const root = parsed.value;
    const root_object = try get_object(root);

    const buffers_value = root_object.get("buffers") orelse return LoadError.MissingBuffer;
    const buffer_views_value = root_object.get("bufferViews") orelse return LoadError.InvalidGltf;
    const accessors_value = root_object.get("accessors") orelse return LoadError.InvalidGltf;

    const buffers = try get_array(buffers_value);
    const buffer_views = try get_array(buffer_views_value);
    const accessors = try get_array(accessors_value);

    if (buffers.items.len == 0) {
        return LoadError.MissingBuffer;
    }

    _ = try parse_buffer_info(buffers.items[0]);

    for (buffer_views.items) |buffer_view_value| {
        _ = try parse_buffer_view_info(buffer_view_value);
    }

    for (accessors.items) |accessor_value| {
        _ = try parse_accessor_info(accessor_value);
    }

    const primitive_info = try parse_first_primitive_info(root);

    _ = primitive_info;

    return LoadError.UnsupportedGltf;
}
