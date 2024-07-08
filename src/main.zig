const std = @import("std");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});

pub fn main() !void {
    if (c.glfwInit() == 0) {
        std.log.err("Failed to initialize GLFW: {}\n", .{c.glfwGetError(null)});
        std.process.exit(1);
    }
    defer c.glfwTerminate();

    var extensionCount: c_uint = 0;
    _ = c.vkEnumerateInstanceExtensionProperties(null, &extensionCount, null);
    std.log.info("Vulkan extension count: {}\n", .{extensionCount});

    const window = c.glfwCreateWindow(800, 600, "Hello, World", null, null) orelse {
        std.log.err("Failed to create GLFW window: {}\n", .{c.glfwGetError(null)});
        std.process.exit(1);
    };
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
