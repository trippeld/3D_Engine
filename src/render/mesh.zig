const math = @import("../core/math.zig");

pub const StaticMesh = enum {
    cube,
    plane,
};

pub const Vertex = struct {
    pos: math.Vec3,
    normal: math.Vec3,
};

pub const cube_vertices = [_]Vertex{
    .{ .pos = math.Vec3.init(-0.5, -0.5, -0.5), .normal = math.Vec3.init(0.0, 0.0, -1.0) },
    .{ .pos = math.Vec3.init(0.5, -0.5, -0.5), .normal = math.Vec3.init(0.0, 0.0, -1.0) },
    .{ .pos = math.Vec3.init(0.5, 0.5, -0.5), .normal = math.Vec3.init(0.0, 0.0, -1.0) },
    .{ .pos = math.Vec3.init(-0.5, 0.5, -0.5), .normal = math.Vec3.init(0.0, 0.0, -1.0) },

    .{ .pos = math.Vec3.init(-0.5, -0.5, 0.5), .normal = math.Vec3.init(0.0, 0.0, 1.0) },
    .{ .pos = math.Vec3.init(0.5, -0.5, 0.5), .normal = math.Vec3.init(0.0, 0.0, 1.0) },
    .{ .pos = math.Vec3.init(0.5, 0.5, 0.5), .normal = math.Vec3.init(0.0, 0.0, 1.0) },
    .{ .pos = math.Vec3.init(-0.5, 0.5, 0.5), .normal = math.Vec3.init(0.0, 0.0, 1.0) },

    .{ .pos = math.Vec3.init(-0.5, -0.5, -0.5), .normal = math.Vec3.init(-1.0, 0.0, 0.0) },
    .{ .pos = math.Vec3.init(-0.5, 0.5, -0.5), .normal = math.Vec3.init(-1.0, 0.0, 0.0) },
    .{ .pos = math.Vec3.init(-0.5, 0.5, 0.5), .normal = math.Vec3.init(-1.0, 0.0, 0.0) },
    .{ .pos = math.Vec3.init(-0.5, -0.5, 0.5), .normal = math.Vec3.init(-1.0, 0.0, 0.0) },

    .{ .pos = math.Vec3.init(0.5, -0.5, -0.5), .normal = math.Vec3.init(1.0, 0.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, 0.5, -0.5), .normal = math.Vec3.init(1.0, 0.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, 0.5, 0.5), .normal = math.Vec3.init(1.0, 0.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, -0.5, 0.5), .normal = math.Vec3.init(1.0, 0.0, 0.0) },

    .{ .pos = math.Vec3.init(-0.5, -0.5, -0.5), .normal = math.Vec3.init(0.0, -1.0, 0.0) },
    .{ .pos = math.Vec3.init(-0.5, -0.5, 0.5), .normal = math.Vec3.init(0.0, -1.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, -0.5, 0.5), .normal = math.Vec3.init(0.0, -1.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, -0.5, -0.5), .normal = math.Vec3.init(0.0, -1.0, 0.0) },

    .{ .pos = math.Vec3.init(-0.5, 0.5, -0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
    .{ .pos = math.Vec3.init(-0.5, 0.5, 0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, 0.5, 0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, 0.5, -0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
};

pub const cube_indices = [_]u32{
    0,  1,  2,  2,  3,  0,
    4,  5,  6,  6,  7,  4,
    8,  9,  10, 10, 11, 8,
    12, 13, 14, 14, 15, 12,
    16, 17, 18, 18, 19, 16,
    20, 21, 22, 22, 23, 20,
};

pub const plane_vertices = [_]Vertex{
    .{ .pos = math.Vec3.init(-0.5, 0.0, -0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, 0.0, -0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
    .{ .pos = math.Vec3.init(0.5, 0.0, 0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
    .{ .pos = math.Vec3.init(-0.5, 0.0, 0.5), .normal = math.Vec3.init(0.0, 1.0, 0.0) },
};

pub const plane_indices = [_]u32{
    0, 1, 2,
    2, 3, 0,
};
