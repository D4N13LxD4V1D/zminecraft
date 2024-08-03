const std = @import("std");

pub const Vec2 = std.meta.Tuple(&.{ f32, f32 });

pub const Vec3 = std.meta.Tuple(&.{ f32, f32, f32 });

pub const Mat4 = std.meta.Tuple(&.{
    std.meta.Tuple(&.{ f32, f32, f32, f32 }),
    std.meta.Tuple(&.{ f32, f32, f32, f32 }),
    std.meta.Tuple(&.{ f32, f32, f32, f32 }),
    std.meta.Tuple(&.{ f32, f32, f32, f32 }),
});

pub const zero: Vec3 = .{ 0.0, 0.0, 0.0 };

pub fn sub(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

pub fn cross(a: Vec3, b: Vec3) Vec3 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

pub fn normalize(a: Vec3) Vec3 {
    const len = std.math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    return .{ a[0] / len, a[1] / len, a[2] / len };
}

pub fn mul(a: Mat4, b: Mat4) Mat4 {
    return .{ .{
        a[0][0] * b[0][0] + a[0][1] * b[1][0] + a[0][2] * b[2][0] + a[0][3] * b[3][0],
        a[0][0] * b[0][1] + a[0][1] * b[1][1] + a[0][2] * b[2][1] + a[0][3] * b[3][1],
        a[0][0] * b[0][2] + a[0][1] * b[1][2] + a[0][2] * b[2][2] + a[0][3] * b[3][2],
        a[0][0] * b[0][3] + a[0][1] * b[1][3] + a[0][2] * b[2][3] + a[0][3] * b[3][3],
    }, .{
        a[1][0] * b[0][0] + a[1][1] * b[1][0] + a[1][2] * b[2][0] + a[1][3] * b[3][0],
        a[1][0] * b[0][1] + a[1][1] * b[1][1] + a[1][2] * b[2][1] + a[1][3] * b[3][1],
        a[1][0] * b[0][2] + a[1][1] * b[1][2] + a[1][2] * b[2][2] + a[1][3] * b[3][2],
        a[1][0] * b[0][3] + a[1][1] * b[1][3] + a[1][2] * b[2][3] + a[1][3] * b[3][3],
    }, .{
        a[2][0] * b[0][0] + a[2][1] * b[1][0] + a[2][2] * b[2][0] + a[2][3] * b[3][0],
        a[2][0] * b[0][1] + a[2][1] * b[1][1] + a[2][2] * b[2][1] + a[2][3] * b[3][1],
        a[2][0] * b[0][2] + a[2][1] * b[1][2] + a[2][2] * b[2][2] + a[2][3] * b[3][2],
        a[2][0] * b[0][3] + a[2][1] * b[1][3] + a[2][2] * b[2][3] + a[2][3] * b[3][3],
    }, .{
        a[3][0] * b[0][0] + a[3][1] * b[1][0] + a[3][2] * b[2][0] + a[3][3] * b[3][0],
        a[3][0] * b[0][1] + a[3][1] * b[1][1] + a[3][2] * b[2][1] + a[3][3] * b[3][1],
        a[3][0] * b[0][2] + a[3][1] * b[1][2] + a[3][2] * b[2][2] + a[3][3] * b[3][2],
        a[3][0] * b[0][3] + a[3][1] * b[1][3] + a[3][2] * b[2][3] + a[3][3] * b[3][3],
    } };
}

pub const identity: Mat4 = .{
    .{ 1.0, 0.0, 0.0, 0.0 },
    .{ 0.0, 1.0, 0.0, 0.0 },
    .{ 0.0, 0.0, 1.0, 0.0 },
    .{ 0.0, 0.0, 0.0, 1.0 },
};

pub fn rotate(self: Mat4, angle: f32, axis: Vec3) Mat4 {
    const c = std.math.cos(angle);
    const s = std.math.sin(angle);
    const t = 1.0 - c;
    const x = axis[0];
    const y = axis[1];
    const z = axis[2];

    return mul(.{
        .{ t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0.0 },
        .{ t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0.0 },
        .{ t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    }, self);
}

pub fn lookAt(eye: Vec3, at: Vec3, up: Vec3) Mat4 {
    const f = normalize(sub(at, eye));
    const s = normalize(cross(f, up));
    const u = cross(s, f);

    return .{
        .{ s[0], u[0], -f[0], 0.0 },
        .{ s[1], u[1], -f[1], 0.0 },
        .{ s[2], u[2], -f[2], 0.0 },
        .{ dot(sub(zero, s), eye), dot(sub(zero, u), eye), dot(f, eye), 1.0 },
    };
}

pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
    const f = 1.0 / std.math.tan(fov / 2.0);
    return .{
        .{ f / aspect, 0.0, 0.0, 0.0 },
        .{ 0.0, f, 0.0, 0.0 },
        .{ 0.0, 0.0, (far + near) / (near - far), -1.0 },
        .{ 0.0, 0.0, (2.0 * far * near) / (near - far), 0.0 },
    };
}
