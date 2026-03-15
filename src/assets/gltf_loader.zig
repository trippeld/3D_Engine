const std = @import("std");
const mesh_data = @import("mesh_data.zig");
const math = @import("../core/math.zig");

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
    byte_stride: usize,
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

fn value_to_index(value: std.json.Value) LoadError!usize {
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
        .byte_stride = try get_optional_integer(object, "byteStride", 0),
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

fn join_buffer_path(
    allocator: std.mem.Allocator,
    gltf_path: []const u8,
    buffer_uri: []const u8,
) ![]u8 {
    const dir = std.fs.path.dirname(gltf_path) orelse ".";
    return try std.fs.path.join(allocator, &.{ dir, buffer_uri });
}

fn read_f32_le(bytes: []const u8, offset: usize) LoadError!f32 {
    if (offset + 4 > bytes.len) {
        return LoadError.InvalidGltf;
    }

    const raw = std.mem.readInt(u32, bytes[offset .. offset + 4][0..4], .little);
    return @bitCast(raw);
}

fn read_u16_le(bytes: []const u8, offset: usize) LoadError!u16 {
    if (offset + 2 > bytes.len) {
        return LoadError.InvalidGltf;
    }

    return std.mem.readInt(u16, bytes[offset .. offset + 2][0..2], .little);
}

fn read_u32_le(bytes: []const u8, offset: usize) LoadError!u32 {
    if (offset + 4 > bytes.len) {
        return LoadError.InvalidGltf;
    }

    return std.mem.readInt(u32, bytes[offset .. offset + 4][0..4], .little);
}

fn accessor_data_start(
    accessor: AccessorInfo,
    buffer_view: BufferViewInfo,
) usize {
    return buffer_view.byte_offset + accessor.byte_offset;
}

fn accessor_stride(
    accessor: AccessorInfo,
    buffer_view: BufferViewInfo,
) LoadError!usize {
    if (buffer_view.byte_stride != 0) {
        return buffer_view.byte_stride;
    }

    if (std.mem.eql(u8, accessor.accessor_type, "VEC3") and accessor.component_type == 5126) {
        return 12;
    }

    if (std.mem.eql(u8, accessor.accessor_type, "SCALAR")) {
        return switch (accessor.component_type) {
            5123 => 2,
            5125 => 4,
            else => LoadError.UnsupportedGltf,
        };
    }

    return LoadError.UnsupportedGltf;
}

fn decode_vec3_accessor(
    allocator: std.mem.Allocator,
    buffer_bytes: []const u8,
    accessor: AccessorInfo,
    buffer_view: BufferViewInfo,
) ![]math.Vec3 {
    if (!std.mem.eql(u8, accessor.accessor_type, "VEC3")) {
        return LoadError.UnsupportedGltf;
    }

    if (accessor.component_type != 5126) {
        return LoadError.UnsupportedGltf;
    }

    const element_size: usize = 12;
    const stride = try accessor_stride(accessor, buffer_view);
    const start = accessor_data_start(accessor, buffer_view);

    if (stride < element_size) {
        return LoadError.InvalidGltf;
    }

    if (accessor.count > 0) {
        const last_element_end = start + (accessor.count - 1) * stride + element_size;
        if (last_element_end > buffer_bytes.len) {
            return LoadError.InvalidGltf;
        }
    }

    const result = try allocator.alloc(math.Vec3, accessor.count);
    errdefer allocator.free(result);

    for (result, 0..) |*vec, i| {
        const base = start + i * stride;
        vec.* = math.Vec3.init(
            try read_f32_le(buffer_bytes, base + 0),
            try read_f32_le(buffer_bytes, base + 4),
            try read_f32_le(buffer_bytes, base + 8),
        );
    }

    return result;
}

fn decode_index_accessor(
    allocator: std.mem.Allocator,
    buffer_bytes: []const u8,
    accessor: AccessorInfo,
    buffer_view: BufferViewInfo,
) ![]u32 {
    if (!std.mem.eql(u8, accessor.accessor_type, "SCALAR")) {
        return LoadError.UnsupportedGltf;
    }

    const stride = try accessor_stride(accessor, buffer_view);
    const start = accessor_data_start(accessor, buffer_view);

    switch (accessor.component_type) {
        5123 => {
            const element_size: usize = 2;

            if (stride < element_size) {
                return LoadError.InvalidGltf;
            }

            if (accessor.count > 0) {
                const last_element_end = start + (accessor.count - 1) * stride + element_size;
                if (last_element_end > buffer_bytes.len) {
                    return LoadError.InvalidGltf;
                }
            }

            const indices = try allocator.alloc(u32, accessor.count);
            errdefer allocator.free(indices);

            for (indices, 0..) |*index, i| {
                const base = start + i * stride;
                index.* = try read_u16_le(buffer_bytes, base);
            }

            return indices;
        },
        5125 => {
            const element_size: usize = 4;

            if (stride < element_size) {
                return LoadError.InvalidGltf;
            }

            if (accessor.count > 0) {
                const last_element_end = start + (accessor.count - 1) * stride + element_size;
                if (last_element_end > buffer_bytes.len) {
                    return LoadError.InvalidGltf;
                }
            }

            const indices = try allocator.alloc(u32, accessor.count);
            errdefer allocator.free(indices);

            for (indices, 0..) |*index, i| {
                const base = start + i * stride;
                index.* = try read_u32_le(buffer_bytes, base);
            }

            return indices;
        },
        else => return LoadError.UnsupportedGltf,
    }
}

fn build_vertices(
    allocator: std.mem.Allocator,
    positions: []const math.Vec3,
    normals: []const math.Vec3,
) ![]mesh_data.Vertex {
    if (positions.len != normals.len) {
        return LoadError.InvalidGltf;
    }

    const vertices = try allocator.alloc(mesh_data.Vertex, positions.len);
    errdefer allocator.free(vertices);

    for (vertices, 0..) |*vertex, i| {
        vertex.* = .{
            .pos = positions[i],
            .normal = normals[i],
        };
    }

    return vertices;
}

fn load_first_mesh_from_dir(
    allocator: std.mem.Allocator,
    dir: std.fs.Dir,
    gltf_path: []const u8,
) !mesh_data.MeshData {
    const json_bytes = try dir.readFileAlloc(
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

    const buffer_info = try parse_buffer_info(buffers.items[0]);

    const buffer_path = try join_buffer_path(allocator, gltf_path, buffer_info.uri);
    defer allocator.free(buffer_path);

    const buffer_bytes = try dir.readFileAlloc(
        allocator,
        buffer_path,
        buffer_info.byte_length,
    );
    defer allocator.free(buffer_bytes);

    const primitive_info = try parse_first_primitive_info(root);

    const position_accessor = try parse_accessor_info(accessors.items[primitive_info.position_accessor_index]);
    const normal_accessor = try parse_accessor_info(accessors.items[primitive_info.normal_accessor_index]);
    const index_accessor = try parse_accessor_info(accessors.items[primitive_info.index_accessor_index]);

    const position_buffer_view = try parse_buffer_view_info(buffer_views.items[position_accessor.buffer_view_index]);
    const normal_buffer_view = try parse_buffer_view_info(buffer_views.items[normal_accessor.buffer_view_index]);
    const index_buffer_view = try parse_buffer_view_info(buffer_views.items[index_accessor.buffer_view_index]);

    if (position_buffer_view.buffer_index != 0 or
        normal_buffer_view.buffer_index != 0 or
        index_buffer_view.buffer_index != 0)
    {
        return LoadError.UnsupportedGltf;
    }

    const positions = try decode_vec3_accessor(
        allocator,
        buffer_bytes,
        position_accessor,
        position_buffer_view,
    );
    defer allocator.free(positions);

    const normals = try decode_vec3_accessor(
        allocator,
        buffer_bytes,
        normal_accessor,
        normal_buffer_view,
    );
    defer allocator.free(normals);

    const vertices = try build_vertices(allocator, positions, normals);
    errdefer allocator.free(vertices);

    const indices = try decode_index_accessor(
        allocator,
        buffer_bytes,
        index_accessor,
        index_buffer_view,
    );
    errdefer allocator.free(indices);

    return .{
        .vertices = vertices,
        .indices = indices,
    };
}

pub fn load_first_mesh(
    allocator: std.mem.Allocator,
    gltf_path: []const u8,
) !mesh_data.MeshData {
    return load_first_mesh_from_dir(allocator, std.fs.cwd(), gltf_path);
}

fn append_u32_le(bytes: *std.ArrayList(u8), value: u32) !void {
    var buffer: [4]u8 = undefined;
    std.mem.writeInt(u32, &buffer, value, .little);
    try bytes.appendSlice(std.testing.allocator, &buffer);
}

fn append_u16_le(bytes: *std.ArrayList(u8), value: u16) !void {
    var buffer: [2]u8 = undefined;
    std.mem.writeInt(u16, &buffer, value, .little);
    try bytes.appendSlice(std.testing.allocator, &buffer);
}

fn append_f32_le(bytes: *std.ArrayList(u8), value: f32) !void {
    try append_u32_le(bytes, @bitCast(value));
}

test "load first mesh from minimal gltf" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var bin_bytes = try std.ArrayList(u8).initCapacity(std.testing.allocator, 0);
    defer bin_bytes.deinit(std.testing.allocator);

    // positions
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);

    try append_f32_le(&bin_bytes, 1.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);

    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);
    try append_f32_le(&bin_bytes, 0.0);

    // normals
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);

    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);

    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);

    // indices
    try append_u16_le(&bin_bytes, 0);
    try append_u16_le(&bin_bytes, 1);
    try append_u16_le(&bin_bytes, 2);

    try tmp.dir.writeFile(.{
        .sub_path = "triangle.bin",
        .data = bin_bytes.items,
    });

    const gltf_json =
        \\{
        \\  "asset": { "version": "2.0" },
        \\  "buffers": [
        \\    { "uri": "triangle.bin", "byteLength": 78 }
        \\  ],
        \\  "bufferViews": [
        \\    { "buffer": 0, "byteOffset": 0,  "byteLength": 36 },
        \\    { "buffer": 0, "byteOffset": 36, "byteLength": 36 },
        \\    { "buffer": 0, "byteOffset": 72, "byteLength": 6 }
        \\  ],
        \\  "accessors": [
        \\    { "bufferView": 0, "byteOffset": 0, "componentType": 5126, "count": 3, "type": "VEC3" },
        \\    { "bufferView": 1, "byteOffset": 0, "componentType": 5126, "count": 3, "type": "VEC3" },
        \\    { "bufferView": 2, "byteOffset": 0, "componentType": 5123, "count": 3, "type": "SCALAR" }
        \\  ],
        \\  "meshes": [
        \\    {
        \\      "primitives": [
        \\        {
        \\          "attributes": {
        \\            "POSITION": 0,
        \\            "NORMAL": 1
        \\          },
        \\          "indices": 2
        \\        }
        \\      ]
        \\    }
        \\  ]
        \\}
    ;

    try tmp.dir.writeFile(.{
        .sub_path = "triangle.gltf",
        .data = gltf_json,
    });

    var loaded = try load_first_mesh_from_dir(
        std.testing.allocator,
        tmp.dir,
        "triangle.gltf",
    );
    defer loaded.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), loaded.vertices.len);
    try std.testing.expectEqual(@as(usize, 3), loaded.indices.len);

    try std.testing.expectEqual(@as(f32, 1.0), loaded.vertices[1].pos.x);
    try std.testing.expectEqual(@as(f32, 1.0), loaded.vertices[2].pos.y);
    try std.testing.expectEqual(@as(f32, 1.0), loaded.vertices[0].normal.z);

    try std.testing.expectEqual(@as(u32, 0), loaded.indices[0]);
    try std.testing.expectEqual(@as(u32, 1), loaded.indices[1]);
    try std.testing.expectEqual(@as(u32, 2), loaded.indices[2]);
}

test "load first mesh from interleaved gltf buffer views" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var bin_bytes = try std.ArrayList(u8).initCapacity(std.testing.allocator, 0);
    defer bin_bytes.deinit(std.testing.allocator);

    // Interleaved vertex layout: position (12 bytes) + normal (12 bytes) = stride 24
    // vertex 0
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);

    // vertex 1
    try append_f32_le(&bin_bytes, 1.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);

    // vertex 2
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 0.0);
    try append_f32_le(&bin_bytes, 1.0);

    // indices
    try append_u16_le(&bin_bytes, 0);
    try append_u16_le(&bin_bytes, 1);
    try append_u16_le(&bin_bytes, 2);

    try tmp.dir.writeFile(.{
        .sub_path = "interleaved.bin",
        .data = bin_bytes.items,
    });

    const gltf_json =
        \\{
        \\  "asset": { "version": "2.0" },
        \\  "buffers": [
        \\    { "uri": "interleaved.bin", "byteLength": 78 }
        \\  ],
        \\  "bufferViews": [
        \\    { "buffer": 0, "byteOffset": 0, "byteLength": 72, "byteStride": 24 },
        \\    { "buffer": 0, "byteOffset": 12, "byteLength": 60, "byteStride": 24 },
        \\    { "buffer": 0, "byteOffset": 72, "byteLength": 6 }
        \\  ],
        \\  "accessors": [
        \\    { "bufferView": 0, "byteOffset": 0, "componentType": 5126, "count": 3, "type": "VEC3" },
        \\    { "bufferView": 1, "byteOffset": 0, "componentType": 5126, "count": 3, "type": "VEC3" },
        \\    { "bufferView": 2, "byteOffset": 0, "componentType": 5123, "count": 3, "type": "SCALAR" }
        \\  ],
        \\  "meshes": [
        \\    {
        \\      "primitives": [
        \\        {
        \\          "attributes": {
        \\            "POSITION": 0,
        \\            "NORMAL": 1
        \\          },
        \\          "indices": 2
        \\        }
        \\      ]
        \\    }
        \\  ]
        \\}
    ;

    try tmp.dir.writeFile(.{
        .sub_path = "interleaved.gltf",
        .data = gltf_json,
    });

    var loaded = try load_first_mesh_from_dir(
        std.testing.allocator,
        tmp.dir,
        "interleaved.gltf",
    );
    defer loaded.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), loaded.vertices.len);
    try std.testing.expectEqual(@as(usize, 3), loaded.indices.len);

    try std.testing.expectEqual(@as(f32, 1.0), loaded.vertices[1].pos.x);
    try std.testing.expectEqual(@as(f32, 1.0), loaded.vertices[2].pos.y);
    try std.testing.expectEqual(@as(f32, 1.0), loaded.vertices[0].normal.z);
}
