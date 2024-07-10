const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig").c;

const WIDTH = 800;
const HEIGHT = 600;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

var instance: c.VkInstance = undefined;
var debugMessenger: c.VkDebugUtilsMessengerEXT = undefined;
var physicalDevice: c.VkPhysicalDevice = undefined;

const QueueFamilyIndices = struct {
    graphicsFamily: ?u32 = null,

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null;
    }
};

pub fn run(allocator: std.mem.Allocator) !void {
    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;
    defer c.glfwTerminate();

    const window = c.glfwCreateWindow(WIDTH, HEIGHT, "zminecraft", null, null) orelse return error.GlfwWindowCreationFailed;
    defer c.glfwDestroyWindow(window);

    try initVulkan(allocator, window);

    c.glfwMakeContextCurrent(window);
    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    cleanup();
}

fn cleanup() void {
    if (enableValidationLayers)
        DestroyDebugUtilsMessengerEXT(null);

    c.vkDestroyInstance(instance, null);
}

fn initVulkan(allocator: std.mem.Allocator, window: *c.GLFWwindow) !void {
    try createInstance(allocator);
    try setupDebugMessenger();
    try pickPhysicalDevice(allocator);
    _ = window;
}

fn createInstance(allocator: std.mem.Allocator) !void {
    if (enableValidationLayers and !(try checkValidationLayerSupport(allocator)))
        return error.ValidationLayerRequestedButNotAvailable;

    const appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "zminecraft",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "zminecraft engine",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
        .pNext = null,
    };

    const extensions = try getRequiredExtensions(allocator);
    defer allocator.free(extensions);

    var debugCreateInfo: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
    populateDebugMessengerCreateInfo(&debugCreateInfo);

    const createInfo = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = if (enableValidationLayers) @intCast(validationLayers.len) else 0,
        .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else null,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
        .pNext = if (enableValidationLayers) &debugCreateInfo else null,
        .flags = if (builtin.os.tag == .macos) c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR else 0,
    };

    if (c.vkCreateInstance(&createInfo, null, &instance) != c.VK_SUCCESS) return error.VulkanInstanceCreationFailed;
}

fn checkValidationLayerSupport(allocator: std.mem.Allocator) !bool {
    var layerCount: u32 = undefined;
    if (c.vkEnumerateInstanceLayerProperties(&layerCount, null) != c.VK_SUCCESS) return error.VulkanValidationLayerEnumerationFailed;

    const availableLayers = try allocator.alloc(c.VkLayerProperties, layerCount);
    defer allocator.free(availableLayers);
    if (c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr) != c.VK_SUCCESS) return error.VulkanValidationLayerEnumerationFailed;

    for (validationLayers) |layerName| {
        var layerFound = false;
        for (availableLayers) |layerProperties| {
            const availableLayerName: [*c]const u8 = @ptrCast(layerProperties.layerName[0..]);
            if (std.mem.eql(u8, std.mem.span(layerName), std.mem.span(availableLayerName))) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) return false;
    }

    return true;
}

fn getRequiredExtensions(allocator: std.mem.Allocator) ![][*]const u8 {
    var glfwExtensionCount: u32 = undefined;
    const glfwExtensions: [*]const [*]const u8 = @ptrCast(c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount));

    var extensions = std.ArrayList([*]const u8).init(allocator);
    defer extensions.deinit();

    try extensions.appendSlice(glfwExtensions[0..glfwExtensionCount]);

    if (builtin.os.tag == .macos)
        try extensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);

    if (enableValidationLayers)
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);

    return extensions.toOwnedSlice();
}

fn setupDebugMessenger() !void {
    if (!enableValidationLayers) return;

    var createInfo: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
    populateDebugMessengerCreateInfo(&createInfo);

    if (CreateDebugUtilsMessengerEXT(&createInfo, null, &debugMessenger) != c.VK_SUCCESS) return error.VulkanDebugMessengerCreationFailed;
}

fn populateDebugMessengerCreateInfo(createInfo: *c.VkDebugUtilsMessengerCreateInfoEXT) void {
    createInfo.* = c.VkDebugUtilsMessengerCreateInfoEXT{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = debugCallback,
        .pUserData = null,
    };
}

fn debugCallback(
    messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageType: c.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: ?*anyopaque,
) callconv(.C) c.VkBool32 {
    _ = messageSeverity;
    _ = messageType;
    _ = pUserData;

    std.log.info("Validation layer: {s}\n", .{pCallbackData.*.pMessage});

    return c.VK_FALSE;
}

fn CreateDebugUtilsMessengerEXT(pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT, pAllocator: ?*const c.VkAllocationCallbacks, pDebugMessenger: *c.VkDebugUtilsMessengerEXT) c.VkResult {
    const func: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT") orelse return c.VK_ERROR_EXTENSION_NOT_PRESENT);
    return func.?(instance, pCreateInfo, pAllocator, pDebugMessenger);
}

fn DestroyDebugUtilsMessengerEXT(pAllocator: ?*const c.VkAllocationCallbacks) void {
    const func: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT") orelse unreachable);
    return func.?(instance, debugMessenger, pAllocator);
}

fn pickPhysicalDevice(allocator: std.mem.Allocator) !void {
    var physicalDeviceCount: u32 = undefined;
    if (c.vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, null) != c.VK_SUCCESS) return error.VulkanPhysicalDeviceEnumerationFailed;
    if (physicalDeviceCount == 0) return error.VulkanNoPhysicalDevicesFound;

    const physicalDevices = try allocator.alloc(c.VkPhysicalDevice, physicalDeviceCount);
    defer allocator.free(physicalDevices);
    if (c.vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, physicalDevices.ptr) != c.VK_SUCCESS) return error.VulkanPhysicalDeviceEnumerationFailed;

    physicalDevice = for (physicalDevices) |device| {
        if (try isDeviceSuitable(allocator, device)) {
            break device;
        }
    } else return error.VulkanNoSuitablePhysicalDeviceFound;
}

fn isDeviceSuitable(allocator: std.mem.Allocator, device: c.VkPhysicalDevice) !bool {
    const indices = try findQueueFamilies(allocator, device);

    return indices.isComplete();
}

fn findQueueFamilies(allocator: std.mem.Allocator, device: c.VkPhysicalDevice) !QueueFamilyIndices {
    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    defer allocator.free(queueFamilies);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var indices = QueueFamilyIndices{};

    for (queueFamilies, 0..) |queueFamily, i| {
        if ((queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
            indices.graphicsFamily = @intCast(i);
        }

        if (indices.isComplete()) break;
    }

    return indices;
}
