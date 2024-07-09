const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig").c;

window: ?*c.GLFWwindow = undefined,
instance: c.VkInstance = undefined,
physicalDevice: c.VkPhysicalDevice = undefined,

pub fn init() @This() {
    var self: @This() = .{};

    self.initWindow();
    self.initVulkan();

    return self;
}

pub fn run(self: @This()) !void {
    while (c.glfwWindowShouldClose(self.window) == c.GLFW_FALSE) {
        c.glfwSwapBuffers(self.window);
        c.glfwPollEvents();
    }
}

fn initWindow(self: *@This()) void {
    if (c.glfwInit() != c.GLFW_TRUE) {
        std.log.err("Failed to initialize GLFW: {}\n", .{c.glfwGetError(null)});
        std.process.exit(1);
    }
    defer c.glfwTerminate();

    self.window = c.glfwCreateWindow(800, 600, "zminecraft", null, null) orelse {
        std.log.err("Failed to create GLFW window: {}\n", .{c.glfwGetError(null)});
        std.process.exit(1);
    };
    defer c.glfwDestroyWindow(self.window);

    c.glfwMakeContextCurrent(self.window);
}

fn initVulkan(self: *@This()) void {
    self.createInstance();
    // self.pickPhysicalDevice();
}

fn createInstance(self: *@This()) void {
    const appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "zminecraft",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "zminecraft",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_3,
    };

    var glfwExtensionCount: u32 = undefined;
    const glfwExtensions = c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Memory leak detected\n", .{});

    var requiredExtensions = std.ArrayList([*c]const u8).init(gpa.allocator());
    defer requiredExtensions.deinit();

    if (glfwExtensionCount > 0)
        requiredExtensions.appendSlice(glfwExtensions[0..glfwExtensionCount]) catch unreachable;

    if (builtin.os.tag == .macos)
        requiredExtensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME) catch unreachable;

    const createInfo = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @intCast(requiredExtensions.items.len),
        .ppEnabledExtensionNames = @ptrCast(requiredExtensions.items),
    };

    if (c.vkCreateInstance(&createInfo, null, &self.instance) != c.VK_SUCCESS) {
        std.log.err("Failed to create Vulkan instance\n", .{});
        std.process.exit(1);
    }
    defer c.vkDestroyInstance(self.instance, null);
}

fn pickPhysicalDevice(self: *@This()) void {
    var physicalDeviceCount: u32 = undefined;
    if (c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, null) != c.VK_SUCCESS) {
        std.log.err("Failed to enumerate GPUs\n", .{});
        std.process.exit(1);
    }

    if (physicalDeviceCount == 0) {
        std.log.err("Failed to find GPUs with Vulkan support\n", .{});
        std.process.exit(1);
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Memory leak detected\n", .{});

    var physicalDevices = std.ArrayList(c.VkPhysicalDevice).init(gpa.allocator());
    defer physicalDevices.deinit();

    physicalDevices.resize(physicalDeviceCount) catch unreachable;
    if (c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, physicalDevices.items.ptr) != c.VK_SUCCESS) {
        std.log.err("Failed to enumerate GPUs\n", .{});
        std.process.exit(1);
    }

    for (physicalDevices.items) |physicalDevice| {
        var properties = c.VkPhysicalDeviceProperties{};
        c.vkGetPhysicalDeviceProperties(physicalDevice, &properties);

        std.log.info("Found GPU: {s}\n", .{properties.deviceName});
    }
}
