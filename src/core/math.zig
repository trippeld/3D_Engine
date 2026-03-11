pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.x - b.x,
            .y = a.y - b.y,
            .z = a.z - b.z,
        };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{
            .x = v.x * s,
            .y = v.y * s,
            .z = v.z * s,
        };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = length(v);
        if (len <= 0.00001) return v;
        return scale(v, 1.0 / len);
    }
};

pub const Mat4 = struct {
    data: [16]f32,

    pub fn identity() Mat4 {
        return .{
            .data = .{
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1,
            },
        };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var out: [16]f32 = undefined;

        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var row: usize = 0;
            while (row < 4) : (row += 1) {
                out[col * 4 + row] =
                    a.data[0 * 4 + row] * b.data[col * 4 + 0] +
                    a.data[1 * 4 + row] * b.data[col * 4 + 1] +
                    a.data[2 * 4 + row] * b.data[col * 4 + 2] +
                    a.data[3 * 4 + row] * b.data[col * 4 + 3];
            }
        }

        return .{ .data = out };
    }

    pub fn perspective(fov_y_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fov_y_radians * 0.5);

        var m = Mat4{ .data = .{0} ** 16 };
        m.data[0] = f / aspect;
        m.data[5] = f;
        m.data[10] = far / (near - far);
        m.data[11] = -1.0;
        m.data[14] = (near * far) / (near - far);

        return m;
    }

    pub fn translate(v: Vec3) Mat4 {
        var m = identity();
        m.data[12] = v.x;
        m.data[13] = v.y;
        m.data[14] = v.z;
        return m;
    }

    pub fn look_at(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = Vec3.normalize(Vec3.sub(center, eye));
        const s = Vec3.normalize(Vec3.cross(f, up));
        const u = Vec3.cross(s, f);

        return .{
            .data = .{
                s.x,               u.x,               -f.x,             0,
                s.y,               u.y,               -f.y,             0,
                s.z,               u.z,               -f.z,             0,
                -Vec3.dot(s, eye), -Vec3.dot(u, eye), Vec3.dot(f, eye), 1,
            },
        };
    }

    pub fn transpose(m: Mat4) Mat4 {
        return .{
            .data = .{
                m.data[0], m.data[4], m.data[8],  m.data[12],
                m.data[1], m.data[5], m.data[9],  m.data[13],
                m.data[2], m.data[6], m.data[10], m.data[14],
                m.data[3], m.data[7], m.data[11], m.data[15],
            },
        };
    }

    pub fn rotate_y(radians: f32) Mat4 {
        const c = @cos(radians);
        const s = @sin(radians);

        return .{
            .data = .{
                c, 0, -s, 0,
                0, 1, 0,  0,
                s, 0, c,  0,
                0, 0, 0,  1,
            },
        };
    }
};
