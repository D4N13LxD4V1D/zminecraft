const std = @import("std");
const c = @import("c.zig").c;

pub fn init() !void {
    if (c.glfwInit() != c.GLFW_TRUE) {
        std.log.err("Failed to initialize GLFW: {}\n", .{c.glfwGetError(null)});
        std.process.exit(1);
    }
    defer c.glfwTerminate();

    const window = c.glfwCreateWindow(800, 600, "Hello, World", null, null) orelse {
        std.log.err("Failed to create GLFW window: {}\n", .{c.glfwGetError(null)});
        std.process.exit(1);
    };
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
