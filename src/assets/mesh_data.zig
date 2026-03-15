const std = @import("std");
const math = @import("../core/math.zig");

pub const Vertex = struct {
    pos: math.Vec3,
    normal: math.Vec3,
};

pub const MeshData = struct {
    vertices: []Vertex,
    indices: []u32,

    pub fn deinit(self: *MeshData, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
        self.* = undefined;
    }
};
