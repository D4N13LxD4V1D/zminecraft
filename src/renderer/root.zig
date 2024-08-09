const std = @import("std");
const builtin = @import("builtin");

const c = @import("c.zig").c;
const vkm = @import("vkm.zig");

const WIDTH = 800;
const HEIGHT = 600;

const MAX_FRAMES_IN_FLIGHT = 2;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
const deviceExtensions = if (builtin.os.tag == .macos) [_][*:0]const u8{ "VK_KHR_portability_subset", c.VK_KHR_SWAPCHAIN_EXTENSION_NAME } else [_][*:0]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

fn CreateDebugUtilsMessengerEXT(instance: c.VkInstance, pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT, pAllocator: ?*const c.VkAllocationCallbacks, pDebugMessenger: *c.VkDebugUtilsMessengerEXT) c.VkResult {
    const func: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT") orelse return c.VK_ERROR_EXTENSION_NOT_PRESENT);
    return func.?(instance, pCreateInfo, pAllocator, pDebugMessenger);
}

fn DestroyDebugUtilsMessengerEXT(instance: c.VkInstance, debugMessenger: c.VkDebugUtilsMessengerEXT, pAllocator: ?*const c.VkAllocationCallbacks) void {
    const func: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT") orelse unreachable);
    return func.?(instance, debugMessenger, pAllocator);
}

const QueueFamilyIndices = struct {
    graphicsFamily: ?u32 = null,
    presentFamily: ?u32 = null,

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null and self.presentFamily != null;
    }
};

const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
    formats: std.ArrayList(c.VkSurfaceFormatKHR) = undefined,
    presentModes: std.ArrayList(c.VkPresentModeKHR) = undefined,

    pub fn init(allocator: std.mem.Allocator) SwapChainSupportDetails {
        return SwapChainSupportDetails{
            .formats = std.ArrayList(c.VkSurfaceFormatKHR).init(allocator),
            .presentModes = std.ArrayList(c.VkPresentModeKHR).init(allocator),
        };
    }

    pub fn deinit(self: *SwapChainSupportDetails) void {
        self.formats.deinit();
        self.presentModes.deinit();
    }
};

const Vertex = struct {
    pos: vkm.Vec2,
    color: vkm.Vec3,
    texCoord: vkm.Vec2,

    pub fn getBindingDescription() c.VkVertexInputBindingDescription {
        return c.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @intCast(@sizeOf(Vertex)),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };
    }

    pub fn getAttributeDescriptions() []const c.VkVertexInputAttributeDescription {
        return &[_]c.VkVertexInputAttributeDescription{
            .{
                .binding = 0,
                .location = 0,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(Vertex, "pos"),
            },
            .{
                .binding = 0,
                .location = 1,
                .format = c.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(Vertex, "color"),
            },
            .{
                .binding = 0,
                .location = 2,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(Vertex, "texCoord"),
            },
        };
    }
};

const UniformBufferObject = struct {
    model: vkm.Mat4,
    view: vkm.Mat4,
    proj: vkm.Mat4,
};

const vertices = [_]Vertex{
    .{ .pos = .{ -0.5, -0.5 }, .color = .{ 1.0, 0.0, 0.0 }, .texCoord = .{ 1.0, 0.0 } },
    .{ .pos = .{ 0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 }, .texCoord = .{ 0.0, 0.0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0.0, 0.0, 1.0 }, .texCoord = .{ 0.0, 1.0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 1.0, 1.0, 1.0 }, .texCoord = .{ 1.0, 1.0 } },
};

const _indices = [_]u16{ 0, 1, 2, 2, 3, 0 };

allocator: std.mem.Allocator = undefined,

window: *c.GLFWwindow = undefined,

instance: c.VkInstance = undefined,
debugMessenger: c.VkDebugUtilsMessengerEXT = undefined,
surface: c.VkSurfaceKHR = undefined,

physicalDevice: c.VkPhysicalDevice = undefined,
device: c.VkDevice = undefined,

graphicsQueue: c.VkQueue = undefined,
presentQueue: c.VkQueue = undefined,

swapChain: c.VkSwapchainKHR = undefined,
swapChainImages: []c.VkImage = undefined,
swapChainImageFormat: c.VkFormat = undefined,
swapChainExtent: c.VkExtent2D = undefined,
swapChainImageViews: []c.VkImageView = undefined,
swapChainFramebuffers: []c.VkFramebuffer = undefined,

renderPass: c.VkRenderPass = undefined,
descriptorSetLayout: c.VkDescriptorSetLayout = undefined,
pipelineLayout: c.VkPipelineLayout = undefined,
graphicsPipeline: c.VkPipeline = undefined,

commandPool: c.VkCommandPool = undefined,

textureImage: c.VkImage = undefined,
textureImageMemory: c.VkDeviceMemory = undefined,
textureImageView: c.VkImageView = undefined,
textureSampler: c.VkSampler = undefined,

vertexBuffer: c.VkBuffer = undefined,
vertexBufferMemory: c.VkDeviceMemory = undefined,
indexBuffer: c.VkBuffer = undefined,
indexBufferMemory: c.VkDeviceMemory = undefined,

uniformBuffers: [MAX_FRAMES_IN_FLIGHT]c.VkBuffer = undefined,
uniformBuffersMemory: [MAX_FRAMES_IN_FLIGHT]c.VkDeviceMemory = undefined,
uniformBuffersData: [MAX_FRAMES_IN_FLIGHT]?*anyopaque = undefined,

descriptorPool: c.VkDescriptorPool = undefined,
descriptorSets: [MAX_FRAMES_IN_FLIGHT]c.VkDescriptorSet = undefined,

commandBuffers: [MAX_FRAMES_IN_FLIGHT]c.VkCommandBuffer = undefined,

imageAvailableSemaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore = undefined,
renderFinishedSemaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore = undefined,
inFlightFences: [MAX_FRAMES_IN_FLIGHT]c.VkFence = undefined,
currentFrame: u32 = 0,

framebufferResized: bool = false,

startTime: std.time.Instant = undefined,

pub fn init(allocator: std.mem.Allocator) !@This() {
    return @This(){
        .allocator = allocator,
        .startTime = try std.time.Instant.now(),
    };
}

pub fn run(self: *@This()) !void {
    try self.initWindow();
    try self.initVulkan();
    try self.mainLoop();
    try self.cleanup();
}

fn initWindow(self: *@This()) !void {
    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);

    self.window = c.glfwCreateWindow(WIDTH, HEIGHT, "zminecraft", null, null) orelse return error.GlfwWindowCreationFailed;
    c.glfwSetWindowUserPointer(self.window, self);
    _ = c.glfwSetFramebufferSizeCallback(self.window, framebufferResizeCallback);
}

fn framebufferResizeCallback(window: ?*c.GLFWwindow, _: c_int, _: c_int) callconv(.C) void {
    var self: *@This() = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window)));
    self.framebufferResized = true;
}

fn initVulkan(self: *@This()) !void {
    try self.createInstance();
    try self.setupDebugMessenger();
    try self.createSurface();
    try self.pickPhysicalDevice();
    try self.createLogicalDevice();
    try self.createSwapChain();
    try self.createImageViews();
    try self.createRenderPass();
    try self.createDescriptorSetLayout();
    try self.createGraphicsPipeline();
    try self.createFramebuffers();
    try self.createCommandPool();
    try self.createTextureImage();
    try self.createTextureImageView();
    try self.createTextureSampler();
    try self.createVertexBuffer();
    try self.createIndexBuffer();
    try self.createUniformBuffers();
    try self.createDescriptorPool();
    try self.createDescriptorSets();
    try self.createCommandBuffers();
    try self.createSyncObjects();
}

fn mainLoop(self: *@This()) !void {
    while (c.glfwWindowShouldClose(self.window) == c.GLFW_FALSE) {
        c.glfwPollEvents();
        try self.drawFrame();
    }

    if (c.vkDeviceWaitIdle(self.device) != c.VK_SUCCESS) return error.VulkanDeviceWaitIdleFailed;
}

fn cleanupSwapChain(self: *@This()) void {
    for (self.swapChainFramebuffers) |framebuffer|
        c.vkDestroyFramebuffer(self.device, framebuffer, null);
    self.allocator.free(self.swapChainFramebuffers);

    for (self.swapChainImageViews) |imageView|
        c.vkDestroyImageView(self.device, imageView, null);
    self.allocator.free(self.swapChainImageViews);

    c.vkDestroySwapchainKHR(self.device, self.swapChain, null);
    self.allocator.free(self.swapChainImages);
}

fn cleanup(self: *@This()) !void {
    self.cleanupSwapChain();

    c.vkDestroySampler(self.device, self.textureSampler, null);
    c.vkDestroyImageView(self.device, self.textureImageView, null);

    c.vkDestroyImage(self.device, self.textureImage, null);
    c.vkFreeMemory(self.device, self.textureImageMemory, null);

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        c.vkDestroyBuffer(self.device, self.uniformBuffers[i], null);
        c.vkFreeMemory(self.device, self.uniformBuffersMemory[i], null);
    }

    c.vkDestroyDescriptorPool(self.device, self.descriptorPool, null);

    c.vkDestroyDescriptorSetLayout(self.device, self.descriptorSetLayout, null);

    c.vkDestroyBuffer(self.device, self.indexBuffer, null);
    c.vkFreeMemory(self.device, self.indexBufferMemory, null);

    c.vkDestroyBuffer(self.device, self.vertexBuffer, null);
    c.vkFreeMemory(self.device, self.vertexBufferMemory, null);

    c.vkDestroyPipeline(self.device, self.graphicsPipeline, null);
    c.vkDestroyPipelineLayout(self.device, self.pipelineLayout, null);

    c.vkDestroyRenderPass(self.device, self.renderPass, null);

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        c.vkDestroySemaphore(self.device, self.renderFinishedSemaphores[i], null);
        c.vkDestroySemaphore(self.device, self.imageAvailableSemaphores[i], null);
        c.vkDestroyFence(self.device, self.inFlightFences[i], null);
    }

    c.vkDestroyCommandPool(self.device, self.commandPool, null);

    c.vkDestroyDevice(self.device, null);

    if (enableValidationLayers)
        DestroyDebugUtilsMessengerEXT(self.instance, self.debugMessenger, null);

    c.vkDestroySurfaceKHR(self.instance, self.surface, null);
    c.vkDestroyInstance(self.instance, null);

    c.glfwDestroyWindow(self.window);
    c.glfwTerminate();
}

fn recreateSwapChain(self: *@This()) !void {
    var width: i32 = undefined;
    var height: i32 = undefined;
    c.glfwGetFramebufferSize(self.window, &width, &height);

    while (self.swapChainExtent.width == 0 or self.swapChainExtent.height == 0) {
        c.glfwGetFramebufferSize(self.window, &width, &height);
        c.glfwWaitEvents();
    }

    if (c.vkDeviceWaitIdle(self.device) != c.VK_SUCCESS) return error.VulkanDeviceWaitFailed;

    self.cleanupSwapChain();

    try self.createSwapChain();
    try self.createImageViews();
    try self.createFramebuffers();
}

fn createInstance(self: *@This()) !void {
    if (enableValidationLayers and !(try self.checkValidationLayerSupport()))
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

    const extensions = try self.getRequiredExtensions();
    defer self.allocator.free(extensions);

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

    if (c.vkCreateInstance(&createInfo, null, &self.instance) != c.VK_SUCCESS) return error.VulkanInstanceCreationFailed;
}

fn checkValidationLayerSupport(self: *@This()) !bool {
    var layerCount: u32 = undefined;
    if (c.vkEnumerateInstanceLayerProperties(&layerCount, null) != c.VK_SUCCESS) return error.VulkanValidationLayerEnumerationFailed;

    const availableLayers = try self.allocator.alloc(c.VkLayerProperties, layerCount);
    defer self.allocator.free(availableLayers);
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

fn getRequiredExtensions(self: *@This()) ![][*]const u8 {
    var glfwExtensionCount: u32 = undefined;
    const glfwExtensions: [*]const [*]const u8 = @ptrCast(c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount));

    var extensions = std.ArrayList([*]const u8).init(self.allocator);
    errdefer extensions.deinit();

    try extensions.appendSlice(glfwExtensions[0..glfwExtensionCount]);

    if (builtin.os.tag == .macos)
        try extensions.appendSlice(&.{ c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME, c.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME });

    if (enableValidationLayers)
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);

    return extensions.toOwnedSlice();
}

fn setupDebugMessenger(self: *@This()) !void {
    if (!enableValidationLayers) return;

    var createInfo: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
    populateDebugMessengerCreateInfo(&createInfo);

    if (CreateDebugUtilsMessengerEXT(self.instance, &createInfo, null, &self.debugMessenger) != c.VK_SUCCESS) return error.VulkanDebugMessengerCreationFailed;
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

    std.debug.print("{s}\n", .{pCallbackData.*.pMessage});

    return c.VK_FALSE;
}

fn createSurface(self: *@This()) !void {
    if (c.glfwCreateWindowSurface(self.instance, self.window, null, &self.surface) != c.VK_SUCCESS) return error.FailedToCreateWindowSurface;
}

fn pickPhysicalDevice(self: *@This()) !void {
    var physicalDeviceCount: u32 = undefined;
    if (c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, null) != c.VK_SUCCESS) return error.VulkanPhysicalDeviceEnumerationFailed;
    if (physicalDeviceCount == 0) return error.VulkanNoPhysicalDevicesFound;

    const physicalDevices = try self.allocator.alloc(c.VkPhysicalDevice, physicalDeviceCount);
    defer self.allocator.free(physicalDevices);
    if (c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, physicalDevices.ptr) != c.VK_SUCCESS) return error.VulkanPhysicalDeviceEnumerationFailed;

    self.physicalDevice = for (physicalDevices) |device| {
        if (try self.isDeviceSuitable(device)) {
            break device;
        }
    } else return error.VulkanNoSuitablePhysicalDeviceFound;
}

fn isDeviceSuitable(self: *@This(), device: c.VkPhysicalDevice) !bool {
    const indices = try self.findQueueFamilies(device);

    const extensionsSupported = try self.checkDeviceExtensionSupport(device);

    const swapChainAdequate = if (extensionsSupported) block: {
        var swapChainSupport = try self.querySwapChainSupport(device);
        defer swapChainSupport.deinit();
        break :block swapChainSupport.formats.items.len != 0 and swapChainSupport.presentModes.items.len != 0;
    } else false;

    var supportedFeatures: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceFeatures(device, &supportedFeatures);

    return indices.isComplete() and extensionsSupported and swapChainAdequate and supportedFeatures.samplerAnisotropy == c.VK_TRUE;
}

fn findQueueFamilies(self: @This(), device: c.VkPhysicalDevice) !QueueFamilyIndices {
    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = try self.allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    defer self.allocator.free(queueFamilies);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var indices = QueueFamilyIndices{};

    for (queueFamilies, 0..) |queueFamily, i| {
        if (queueFamily.queueCount > 0 and (queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0)
            indices.graphicsFamily = @intCast(i);

        var presentSupport: c.VkBool32 = undefined;
        if (c.vkGetPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), self.surface, &presentSupport) != c.VK_SUCCESS) return error.VulkanSurfaceSupportCheckFailed;

        if (queueFamily.queueCount > 0 and presentSupport != 0)
            indices.presentFamily = @intCast(i);

        if (indices.isComplete()) break;
    }

    return indices;
}

fn checkDeviceExtensionSupport(self: *@This(), device: c.VkPhysicalDevice) !bool {
    var extensionCount: u32 = undefined;
    if (c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, null) != c.VK_SUCCESS) return error.VulkanDeviceExtensionEnumerationFailed;

    const availableExtensions = try self.allocator.alloc(c.VkExtensionProperties, extensionCount);
    defer self.allocator.free(availableExtensions);

    if (c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, availableExtensions.ptr) != c.VK_SUCCESS) return error.VulkanDeviceExtensionEnumerationFailed;

    var requiredExtensions = std.HashMap(
        [*:0]const u8,
        void,
        struct {
            pub fn hash(_: @This(), value: [*:0]const u8) u64 {
                var h: u32 = 2166136261;
                var i: usize = 0;
                while (value[i] != 0) : (i += 1) {
                    h ^= value[i];
                    h *%= 16777619;
                }
                return h;
            }

            pub fn eql(_: @This(), value: [*:0]const u8, other: [*:0]const u8) bool {
                return std.mem.eql(u8, std.mem.span(value), std.mem.span(other));
            }
        },
        std.hash_map.default_max_load_percentage,
    ).init(self.allocator);
    defer requiredExtensions.deinit();

    for (deviceExtensions) |extension|
        try requiredExtensions.put(extension, {});

    for (availableExtensions) |extension|
        _ = requiredExtensions.remove(@ptrCast(&extension.extensionName));

    return requiredExtensions.count() == 0;
}

fn querySwapChainSupport(self: @This(), device: c.VkPhysicalDevice) !SwapChainSupportDetails {
    var details = SwapChainSupportDetails.init(self.allocator);
    if (c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, self.surface, &details.capabilities) != c.VK_SUCCESS) return error.VulkanSurfaceCapabilitiesQueryFailed;

    var formatCount: u32 = undefined;
    if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &formatCount, null) != c.VK_SUCCESS) return error.VulkanSurfaceFormatsQueryFailed;

    if (formatCount != 0) {
        try details.formats.resize(formatCount);
        if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &formatCount, details.formats.items.ptr) != c.VK_SUCCESS) return error.VulkanSurfaceFormatsQueryFailed;
    }

    var presentModeCount: u32 = undefined;
    if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &presentModeCount, null) != c.VK_SUCCESS) return error.VulkanSurfacePresentModesQueryFailed;

    if (presentModeCount != 0) {
        try details.presentModes.resize(presentModeCount);
        if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &presentModeCount, details.presentModes.items.ptr) != c.VK_SUCCESS) return error.VulkanSurfacePresentModesQueryFailed;
    }

    return details;
}

fn createLogicalDevice(self: *@This()) !void {
    const indices = try self.findQueueFamilies(self.physicalDevice);

    var queueCreateInfos = std.ArrayList(c.VkDeviceQueueCreateInfo).init(self.allocator);
    defer queueCreateInfos.deinit();

    const allQueueFamilies = [_]u32{ indices.graphicsFamily.?, indices.presentFamily.? };
    const uniqueQueueFamilies = if (indices.graphicsFamily.? == indices.presentFamily.?) allQueueFamilies[0..1] else allQueueFamilies[0..2];

    var queuePriority: f32 = 1.0;
    for (uniqueQueueFamilies) |queueFamily| {
        const queueCreateInfo = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queueFamily,
            .queueCount = 1,
            .pQueuePriorities = &queuePriority,
            .pNext = null,
            .flags = 0,
        };

        try queueCreateInfos.append(queueCreateInfo);
    }

    const deviceFeatures = c.VkPhysicalDeviceFeatures{
        .samplerAnisotropy = c.VK_TRUE,
    };

    const createInfo = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = @intCast(queueCreateInfos.items.len),
        .pQueueCreateInfos = queueCreateInfos.items.ptr,
        .enabledExtensionCount = @intCast(deviceExtensions.len),
        .ppEnabledExtensionNames = &deviceExtensions,
        .pEnabledFeatures = &deviceFeatures,
        .enabledLayerCount = if (enableValidationLayers) @intCast(validationLayers.len) else 0,
        .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else null,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateDevice(self.physicalDevice, &createInfo, null, &self.device) != c.VK_SUCCESS) return error.VulkanLogicalDeviceCreationFailed;

    c.vkGetDeviceQueue(self.device, indices.graphicsFamily.?, 0, &self.graphicsQueue);
    c.vkGetDeviceQueue(self.device, indices.presentFamily.?, 0, &self.presentQueue);
}

fn createSwapChain(self: *@This()) !void {
    var swapChainSupport = try self.querySwapChainSupport(self.physicalDevice);
    defer swapChainSupport.deinit();

    const surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats.items);
    const presentMode = chooseSwapPresentMode(swapChainSupport.presentModes.items);
    const extent = chooseSwapExtent(self.window, swapChainSupport.capabilities);

    var imageCount = swapChainSupport.capabilities.minImageCount + 1;
    if (swapChainSupport.capabilities.maxImageCount > 0 and imageCount > swapChainSupport.capabilities.maxImageCount)
        imageCount = swapChainSupport.capabilities.maxImageCount;

    const indices = try self.findQueueFamilies(self.physicalDevice);
    const queueFamilyIndices = [_]u32{ indices.graphicsFamily.?, indices.presentFamily.? };

    const createInfo = c.VkSwapchainCreateInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = self.surface,
        .minImageCount = imageCount,
        .imageFormat = surfaceFormat.format,
        .imageColorSpace = surfaceFormat.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = if (indices.graphicsFamily != indices.presentFamily) c.VK_SHARING_MODE_CONCURRENT else c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = if (indices.graphicsFamily != indices.presentFamily) 2 else 0,
        .pQueueFamilyIndices = if (indices.graphicsFamily != indices.presentFamily) &queueFamilyIndices else null,
        .preTransform = swapChainSupport.capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = presentMode,
        .clipped = c.VK_TRUE,
        .oldSwapchain = null,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateSwapchainKHR(self.device, &createInfo, null, &self.swapChain) != c.VK_SUCCESS) return error.VulkanSwapChainCreationFailed;

    if (c.vkGetSwapchainImagesKHR(self.device, self.swapChain, &imageCount, null) != c.VK_SUCCESS) return error.VulkanSwapChainImageQueryFailed;

    self.swapChainImages = try self.allocator.alloc(c.VkImage, imageCount);
    errdefer self.allocator.free(self.swapChainImages);

    if (c.vkGetSwapchainImagesKHR(self.device, self.swapChain, &imageCount, self.swapChainImages.ptr) != c.VK_SUCCESS) return error.VulkanSwapChainImageQueryFailed;

    self.swapChainImageFormat = surfaceFormat.format;
    self.swapChainExtent = extent;
}

fn chooseSwapSurfaceFormat(availableFormats: []c.VkSurfaceFormatKHR) c.VkSurfaceFormatKHR {
    for (availableFormats) |availableFormat| {
        if (availableFormat.format == c.VK_FORMAT_B8G8R8A8_SRGB and availableFormat.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            return availableFormat;
    }

    return availableFormats[0];
}

fn chooseSwapPresentMode(availablePresentModes: []c.VkPresentModeKHR) c.VkPresentModeKHR {
    for (availablePresentModes) |availablePresentMode| {
        if (availablePresentMode == c.VK_PRESENT_MODE_MAILBOX_KHR)
            return availablePresentMode;
    }

    return c.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapExtent(window: *c.GLFWwindow, capabilities: c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32))
        return capabilities.currentExtent;

    var width: i32 = undefined;
    var height: i32 = undefined;

    c.glfwGetFramebufferSize(window, &width, &height);

    var actualExtent = c.VkExtent2D{
        .width = @intCast(width),
        .height = @intCast(height),
    };

    actualExtent.width = std.math.clamp(actualExtent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
    actualExtent.height = std.math.clamp(actualExtent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);

    return actualExtent;
}

fn createImageView(self: *@This(), image: c.VkImage, format: c.VkFormat) !c.VkImageView {
    const viewInfo = c.VkImageViewCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .format = format,
        .components = c.VkComponentMapping{
            .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .pNext = null,
        .flags = 0,
    };

    var imageView: c.VkImageView = undefined;
    if (c.vkCreateImageView(self.device, &viewInfo, null, &imageView) != c.VK_SUCCESS) return error.VulkanImageViewCreationFailed;

    return imageView;
}

fn createImageViews(self: *@This()) !void {
    self.swapChainImageViews = try self.allocator.alloc(c.VkImageView, self.swapChainImages.len);
    errdefer self.allocator.free(self.swapChainImageViews);

    for (self.swapChainImages, 0..) |swapChainImage, i|
        self.swapChainImageViews[i] = try self.createImageView(swapChainImage, self.swapChainImageFormat);
}

fn createRenderPass(self: *@This()) !void {
    const colorAttachment = c.VkAttachmentDescription{
        .format = self.swapChainImageFormat,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };

    const colorAttachmentRef = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const subpass = c.VkSubpassDescription{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &colorAttachmentRef,
        .pDepthStencilAttachment = null,
        .inputAttachmentCount = 0,
        .pInputAttachments = null,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null,
        .pResolveAttachments = null,
        .flags = 0,
    };

    const dependency = c.VkSubpassDependency{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        .dependencyFlags = 0,
    };

    const renderPassInfo = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &colorAttachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateRenderPass(self.device, &renderPassInfo, null, &self.renderPass) != c.VK_SUCCESS) return error.VulkanRenderPassCreationFailed;
}

fn createDescriptorSetLayout(self: *@This()) !void {
    const uboLayoutBinding = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
        .pImmutableSamplers = null,
    };

    const samplerLayoutBinding = c.VkDescriptorSetLayoutBinding{
        .binding = 1,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .pImmutableSamplers = null,
    };

    const bindings = [_]c.VkDescriptorSetLayoutBinding{ uboLayoutBinding, samplerLayoutBinding };

    const layoutInfo = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = bindings.len,
        .pBindings = &bindings,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateDescriptorSetLayout(self.device, &layoutInfo, null, &self.descriptorSetLayout) != c.VK_SUCCESS) return error.VulkanDescriptorSetLayoutCreationFailed;
}

fn createGraphicsPipeline(self: *@This()) !void {
    const vertShaderCode align(4) = @embedFile("vert.spv").*;
    const fragShaderCode align(4) = @embedFile("frag.spv").*;

    const vertshaderModule = try self.createShaderModule(&vertShaderCode);
    defer c.vkDestroyShaderModule(self.device, vertshaderModule, null);

    const fragShaderModule = try self.createShaderModule(&fragShaderCode);
    defer c.vkDestroyShaderModule(self.device, fragShaderModule, null);

    const vertShaderStageInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertshaderModule,
        .pName = "main",
        .pSpecializationInfo = null,
        .pNext = null,
        .flags = 0,
    };

    const fragShaderStageInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragShaderModule,
        .pName = "main",
        .pSpecializationInfo = null,
        .pNext = null,
        .flags = 0,
    };

    const shaderStages = [_]c.VkPipelineShaderStageCreateInfo{ vertShaderStageInfo, fragShaderStageInfo };

    const bindingDescription = Vertex.getBindingDescription();
    const attributeDescriptions = Vertex.getAttributeDescriptions();

    const vertexInputInfo = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &bindingDescription,
        .vertexAttributeDescriptionCount = @intCast(attributeDescriptions.len),
        .pVertexAttributeDescriptions = attributeDescriptions.ptr,
        .pNext = null,
        .flags = 0,
    };

    const inputAssembly = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };

    const dynamicStates = [_]c.VkDynamicState{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
        c.VK_DYNAMIC_STATE_LINE_WIDTH,
        c.VK_DYNAMIC_STATE_DEPTH_BIAS,
        c.VK_DYNAMIC_STATE_BLEND_CONSTANTS,
        c.VK_DYNAMIC_STATE_DEPTH_BOUNDS,
        c.VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK,
        c.VK_DYNAMIC_STATE_STENCIL_WRITE_MASK,
        c.VK_DYNAMIC_STATE_STENCIL_REFERENCE,
    };

    const dynamicState = c.VkPipelineDynamicStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = @intCast(dynamicStates.len),
        .pDynamicStates = &dynamicStates,
        .pNext = null,
        .flags = 0,
    };

    const viewportState = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = null,
        .scissorCount = 1,
        .pScissors = null,
        .pNext = null,
        .flags = 0,
    };

    const rasterizer = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
        .pNext = null,
        .flags = 0,
    };

    const multisampling = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .minSampleShading = 1.0,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };

    const colorBlendAttachment = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_TRUE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_SRC_ALPHA,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    const colorBlending = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlendAttachment,
        .blendConstants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        .pNext = null,
        .flags = 0,
    };

    const pipelineLayoutInfo = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &self.descriptorSetLayout,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreatePipelineLayout(self.device, &pipelineLayoutInfo, null, &self.pipelineLayout) != c.VK_SUCCESS) return error.VulkanPipelineLayoutCreationFailed;

    const pipelineInfo = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = @intCast(shaderStages.len),
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputInfo,
        .pInputAssemblyState = &inputAssembly,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &colorBlending,
        .pDynamicState = &dynamicState,
        .layout = self.pipelineLayout,
        .renderPass = self.renderPass,
        .subpass = 0,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateGraphicsPipelines(self.device, null, 1, &pipelineInfo, null, &self.graphicsPipeline) != c.VK_SUCCESS) return error.VulkanGraphicsPipelineCreationFailed;
}

fn createShaderModule(self: *@This(), code: []align(@alignOf(u32)) const u8) !c.VkShaderModule {
    const createInfo = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = @intCast(code.len),
        .pCode = std.mem.bytesAsSlice(u32, code).ptr,
        .pNext = null,
        .flags = 0,
    };

    var shaderModule: c.VkShaderModule = undefined;
    if (c.vkCreateShaderModule(self.device, &createInfo, null, &shaderModule) != c.VK_SUCCESS) return error.VulkanShaderModuleCreationFailed;

    return shaderModule;
}

fn createFramebuffers(self: *@This()) !void {
    self.swapChainFramebuffers = try self.allocator.alloc(c.VkFramebuffer, self.swapChainImageViews.len);
    errdefer self.allocator.free(self.swapChainFramebuffers);

    for (self.swapChainImageViews, 0..) |imageView, i| {
        const attachments = [_]c.VkImageView{imageView};

        const framebufferInfo = c.VkFramebufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = self.renderPass,
            .attachmentCount = @intCast(attachments.len),
            .pAttachments = &attachments,
            .width = self.swapChainExtent.width,
            .height = self.swapChainExtent.height,
            .layers = 1,
            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateFramebuffer(self.device, &framebufferInfo, null, &self.swapChainFramebuffers[i]) != c.VK_SUCCESS) return error.VulkanFramebufferCreationFailed;
    }
}

fn createCommandPool(self: *@This()) !void {
    const queueFamilyIndices = try self.findQueueFamilies(self.physicalDevice);

    const poolInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = queueFamilyIndices.graphicsFamily.?,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .pNext = null,
    };

    if (c.vkCreateCommandPool(self.device, &poolInfo, null, &self.commandPool) != c.VK_SUCCESS) return error.VulkanCommandPoolCreationFailed;
}

fn createImage(self: *@This(), width: u32, height: u32, format: c.VkFormat, tiling: c.VkImageTiling, usage: c.VkImageUsageFlags, properties: c.VkMemoryPropertyFlags, image: *c.VkImage, imageMemory: *c.VkDeviceMemory) !void {
    const imageInfo = c.VkImageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = c.VK_IMAGE_TYPE_2D,
        .extent = c.VkExtent3D{
            .width = width,
            .height = height,
            .depth = 1,
        },
        .mipLevels = 1,
        .arrayLayers = 1,
        .format = format,
        .tiling = tiling,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .flags = 0,
    };

    if (c.vkCreateImage(self.device, &imageInfo, null, image) != c.VK_SUCCESS) return error.VulkanImageCreationFailed;

    var memRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetImageMemoryRequirements(self.device, image.*, &memRequirements);

    const allocInfo = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try self.findMemoryType(memRequirements.memoryTypeBits, properties),
        .pNext = null,
    };

    if (c.vkAllocateMemory(self.device, &allocInfo, null, imageMemory) != c.VK_SUCCESS) return error.VulkanImageMemoryAllocationFailed;

    if (c.vkBindImageMemory(self.device, image.*, imageMemory.*, 0) != c.VK_SUCCESS) return error.VulkanImageMemoryBindingFailed;
}

fn createTextureImage(self: *@This()) !void {
    var texWidth: c_int = undefined;
    var texHeight: c_int = undefined;
    var texChannels: c_int = undefined;

    const pixels = c.stbi_load("textures/texture.jpg", &texWidth, &texHeight, &texChannels, c.STBI_rgb_alpha) orelse return error.VulkanTextureImageLoadingFailed;
    const imageSize: c.VkDeviceSize = @intCast(texWidth * texHeight * 4);

    var stagingBuffer: c.VkBuffer = undefined;
    var stagingBufferMemory: c.VkDeviceMemory = undefined;

    try self.createBuffer(imageSize, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &stagingBuffer, &stagingBufferMemory);
    var data: ?*anyopaque = undefined;
    if (c.vkMapMemory(self.device, stagingBufferMemory, 0, imageSize, 0, &data) != c.VK_SUCCESS) return error.VulkanTextureImageMemoryMappingFailed;

    @memcpy(@as([*]u8, @ptrCast(data.?))[0..imageSize], pixels[0..imageSize]);
    c.vkUnmapMemory(self.device, stagingBufferMemory);

    c.stbi_image_free(pixels);

    try self.createImage(@intCast(texWidth), @intCast(texHeight), c.VK_FORMAT_R8G8B8A8_SRGB, c.VK_IMAGE_TILING_OPTIMAL, c.VK_IMAGE_USAGE_TRANSFER_DST_BIT | c.VK_IMAGE_USAGE_SAMPLED_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &self.textureImage, &self.textureImageMemory);

    try self.transitionLayoutImages(self.textureImage, c.VK_FORMAT_R8G8B8A8_SRGB, c.VK_IMAGE_LAYOUT_UNDEFINED, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);
    try self.copyBufferToImage(stagingBuffer, self.textureImage, @intCast(texWidth), @intCast(texHeight));
    try self.transitionLayoutImages(self.textureImage, c.VK_FORMAT_R8G8B8A8_SRGB, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

    c.vkDestroyBuffer(self.device, stagingBuffer, null);
    c.vkFreeMemory(self.device, stagingBufferMemory, null);
}

fn transitionLayoutImages(self: @This(), image: c.VkImage, format: c.VkFormat, oldLayout: c.VkImageLayout, newLayout: c.VkImageLayout) !void {
    const commandBuffer = try self.beginSingleTimeCommands();

    _ = format;

    var barrier = c.VkImageMemoryBarrier{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .srcAccessMask = 0,
        .dstAccessMask = 0,
    };

    var sourceStage: c.VkPipelineStageFlags = undefined;
    var destinationStage: c.VkPipelineStageFlags = undefined;

    if (oldLayout == c.VK_IMAGE_LAYOUT_UNDEFINED and newLayout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.srcAccessMask = c.VK_ACCESS_NONE;
        barrier.dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;

        sourceStage = c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destinationStage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (oldLayout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = c.VK_ACCESS_SHADER_READ_BIT;

        sourceStage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
        destinationStage = c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else {
        return error.VulkanUnsupportedImageLayoutTransition;
    }

    c.vkCmdPipelineBarrier(commandBuffer, sourceStage, destinationStage, 0, 0, null, 0, null, 1, &barrier);

    try self.endSingleTimeCommands(commandBuffer);
}

fn copyBufferToImage(self: *@This(), buffer: c.VkBuffer, image: c.VkImage, width: u32, height: u32) !void {
    const commandBuffer = try self.beginSingleTimeCommands();

    const region = c.VkBufferImageCopy{
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,
        .imageSubresource = c.VkImageSubresourceLayers{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .imageOffset = c.VkOffset3D{ .x = 0, .y = 0, .z = 0 },
        .imageExtent = c.VkExtent3D{ .width = width, .height = height, .depth = 1 },
    };

    c.vkCmdCopyBufferToImage(commandBuffer, buffer, image, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);

    try self.endSingleTimeCommands(commandBuffer);
}

fn createTextureImageView(self: *@This()) !void {
    self.textureImageView = try self.createImageView(self.textureImage, c.VK_FORMAT_R8G8B8A8_SRGB);
}

fn createTextureSampler(self: *@This()) !void {
    var properties = c.VkPhysicalDeviceProperties{};
    c.vkGetPhysicalDeviceProperties(self.physicalDevice, &properties);

    const samplerInfo = c.VkSamplerCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = c.VK_FILTER_LINEAR,
        .minFilter = c.VK_FILTER_LINEAR,
        .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .anisotropyEnable = c.VK_TRUE,
        .maxAnisotropy = properties.limits.maxSamplerAnisotropy,
        .borderColor = c.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = c.VK_FALSE,
        .compareEnable = c.VK_FALSE,
        .compareOp = c.VK_COMPARE_OP_ALWAYS,
        .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
        .mipLodBias = 0.0,
        .minLod = 0.0,
        .maxLod = 0.0,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateSampler(self.device, &samplerInfo, null, &self.textureSampler) != c.VK_SUCCESS) return error.VulkanTextureSamplerCreationFailed;
}

fn createVertexBuffer(self: *@This()) !void {
    const bufferSize: c.VkDeviceSize = @intCast(@sizeOf(Vertex) * vertices.len);

    var stagingBuffer: c.VkBuffer = undefined;
    var stagingBufferMemory: c.VkDeviceMemory = undefined;
    try self.createBuffer(bufferSize, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &stagingBuffer, &stagingBufferMemory);

    var data: ?*anyopaque = undefined;
    if (c.vkMapMemory(self.device, stagingBufferMemory, 0, bufferSize, 0, &data) != c.VK_SUCCESS) return error.VulkanVertexBufferMemoryMappingFailed;
    @memcpy(@as([*]u8, @ptrCast(data.?))[0..bufferSize], std.mem.sliceAsBytes(&vertices));
    c.vkUnmapMemory(self.device, stagingBufferMemory);

    try self.createBuffer(bufferSize, c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &self.vertexBuffer, &self.vertexBufferMemory);
    try self.copyBuffer(stagingBuffer, self.vertexBuffer, bufferSize);

    c.vkDestroyBuffer(self.device, stagingBuffer, null);
    c.vkFreeMemory(self.device, stagingBufferMemory, null);
}

fn createIndexBuffer(self: *@This()) !void {
    const bufferSize: c.VkDeviceSize = @intCast(@sizeOf(u16) * _indices.len);

    var stagingBuffer: c.VkBuffer = undefined;
    var stagingBufferMemory: c.VkDeviceMemory = undefined;
    try self.createBuffer(bufferSize, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &stagingBuffer, &stagingBufferMemory);

    var data: ?*anyopaque = undefined;
    if (c.vkMapMemory(self.device, stagingBufferMemory, 0, bufferSize, 0, &data) != c.VK_SUCCESS) return error.VulkanVertexBufferMemoryMappingFailed;
    @memcpy(@as([*]u8, @ptrCast(data.?))[0..bufferSize], std.mem.sliceAsBytes(&_indices));
    c.vkUnmapMemory(self.device, stagingBufferMemory);

    try self.createBuffer(bufferSize, c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &self.indexBuffer, &self.indexBufferMemory);
    try self.copyBuffer(stagingBuffer, self.indexBuffer, bufferSize);

    c.vkDestroyBuffer(self.device, stagingBuffer, null);
    c.vkFreeMemory(self.device, stagingBufferMemory, null);
}

fn createBuffer(self: *@This(), size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags, buffer: *c.VkBuffer, bufferMemory: *c.VkDeviceMemory) !void {
    const bufferInfo = c.VkBufferCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateBuffer(self.device, &bufferInfo, null, buffer) != c.VK_SUCCESS) return error.VulkanBufferCreationFailed;

    var memRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(self.device, buffer.*, &memRequirements);

    const allocInfo = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try self.findMemoryType(memRequirements.memoryTypeBits, properties),
        .pNext = null,
    };

    if (c.vkAllocateMemory(self.device, &allocInfo, null, bufferMemory) != c.VK_SUCCESS) return error.VulkanBufferMemoryAllocationFailed;
    if (c.vkBindBufferMemory(self.device, buffer.*, bufferMemory.*, 0) != c.VK_SUCCESS) return error.VulkanBufferMemoryBindingFailed;
}

fn findMemoryType(self: *@This(), typeFilter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    var memProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(self.physicalDevice, &memProperties);

    for (0..memProperties.memoryTypeCount) |i| {
        if (typeFilter & (@as(u32, 1) << @truncate(i)) != 0 and (memProperties.memoryTypes[i].propertyFlags & properties) == properties)
            return @truncate(i);
    }

    return error.VulkanMemoryTypeNotFound;
}

fn beginSingleTimeCommands(self: @This()) !c.VkCommandBuffer {
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = self.commandPool,
        .commandBufferCount = 1,
        .pNext = null,
    };

    var commandBuffer: c.VkCommandBuffer = undefined;
    if (c.vkAllocateCommandBuffers(self.device, &allocInfo, &commandBuffer) != c.VK_SUCCESS) return error.VulkanCommandBufferAllocationFailed;

    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pNext = null,
    };

    if (c.vkBeginCommandBuffer(commandBuffer, &beginInfo) != c.VK_SUCCESS) return error.VulkanCommandBufferBeginFailed;

    return commandBuffer;
}

fn endSingleTimeCommands(self: @This(), commandBuffer: c.VkCommandBuffer) !void {
    if (c.vkEndCommandBuffer(commandBuffer) != c.VK_SUCCESS) return error.VulkanCommandBufferEndFailed;

    const submitInfo = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffer,
        .pNext = null,
    };

    if (c.vkQueueSubmit(self.graphicsQueue, 1, &submitInfo, null) != c.VK_SUCCESS) return error.VulkanQueueSubmissionFailed;
    if (c.vkQueueWaitIdle(self.graphicsQueue) != c.VK_SUCCESS) return error.VulkanQueueWaitFailed;

    c.vkFreeCommandBuffers(self.device, self.commandPool, 1, &commandBuffer);
}

fn copyBuffer(self: *@This(), srcBuffer: c.VkBuffer, dstBuffer: c.VkBuffer, size: c.VkDeviceSize) !void {
    const commandBuffer = try self.beginSingleTimeCommands();

    const copyRegion = c.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };

    c.vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    try self.endSingleTimeCommands(commandBuffer);
}

fn createUniformBuffers(self: *@This()) !void {
    const bufferSize: c.VkDeviceSize = @intCast(@sizeOf(UniformBufferObject));

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        try self.createBuffer(bufferSize, c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &self.uniformBuffers[i], &self.uniformBuffersMemory[i]);
        if (c.vkMapMemory(self.device, self.uniformBuffersMemory[i], 0, bufferSize, 0, &self.uniformBuffersData[i]) != c.VK_SUCCESS) return error.VulkanUniformBufferMemoryMappingFailed;
    }
}

fn createDescriptorPool(self: *@This()) !void {
    const poolSizes = [_]c.VkDescriptorPoolSize{ .{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = @intCast(MAX_FRAMES_IN_FLIGHT),
    }, .{
        .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = @intCast(MAX_FRAMES_IN_FLIGHT),
    } };

    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .maxSets = @intCast(MAX_FRAMES_IN_FLIGHT),
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateDescriptorPool(self.device, &poolInfo, null, &self.descriptorPool) != c.VK_SUCCESS) return error.VulkanDescriptorPoolCreationFailed;
}

fn createDescriptorSets(self: *@This()) !void {
    var layouts: [MAX_FRAMES_IN_FLIGHT]c.VkDescriptorSetLayout = undefined;

    for (0..MAX_FRAMES_IN_FLIGHT) |i|
        layouts[i] = self.descriptorSetLayout;

    const allocInfo = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = self.descriptorPool,
        .descriptorSetCount = @intCast(MAX_FRAMES_IN_FLIGHT),
        .pSetLayouts = &layouts,
        .pNext = null,
    };

    if (c.vkAllocateDescriptorSets(self.device, &allocInfo, &self.descriptorSets) != c.VK_SUCCESS) return error.VulkanDescriptorSetAllocationFailed;

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        const bufferInfo = c.VkDescriptorBufferInfo{
            .buffer = self.uniformBuffers[i],
            .offset = 0,
            .range = @intCast(@sizeOf(UniformBufferObject)),
        };

        const imageInfo = c.VkDescriptorImageInfo{
            .sampler = self.textureSampler,
            .imageView = self.textureImageView,
            .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        };

        const descriptorWrites = [_]c.VkWriteDescriptorSet{
            .{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = self.descriptorSets[i],
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1,
                .pBufferInfo = &bufferInfo,
                .pImageInfo = null,
                .pTexelBufferView = null,
                .pNext = null,
            },
            .{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = self.descriptorSets[i],
                .dstBinding = 1,
                .dstArrayElement = 0,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = 1,
                .pBufferInfo = null,
                .pImageInfo = &imageInfo,
                .pTexelBufferView = null,
                .pNext = null,
            },
        };

        c.vkUpdateDescriptorSets(self.device, @intCast(descriptorWrites.len), &descriptorWrites, 0, null);
    }
}

fn createCommandBuffers(self: *@This()) !void {
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = self.commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(self.commandBuffers.len),
        .pNext = null,
    };

    if (c.vkAllocateCommandBuffers(self.device, &allocInfo, &self.commandBuffers) != c.VK_SUCCESS) return error.VulkanCommandBufferAllocationFailed;
}

fn createSyncObjects(self: *@This()) !void {
    const semaphoreInfo = c.VkSemaphoreCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    const fenceInfo = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        .pNext = null,
    };

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        if (c.vkCreateSemaphore(self.device, &semaphoreInfo, null, &self.imageAvailableSemaphores[i]) != c.VK_SUCCESS) return error.VulkanSemaphoreCreationFailed;
        if (c.vkCreateSemaphore(self.device, &semaphoreInfo, null, &self.renderFinishedSemaphores[i]) != c.VK_SUCCESS) return error.VulkanSemaphoreCreationFailed;
        if (c.vkCreateFence(self.device, &fenceInfo, null, &self.inFlightFences[i]) != c.VK_SUCCESS) return error.VulkanFenceCreationFailed;
    }
}

fn drawFrame(self: *@This()) !void {
    if (c.vkWaitForFences(self.device, 1, &self.inFlightFences[self.currentFrame], c.VK_TRUE, std.math.maxInt(u64)) != c.VK_SUCCESS) return error.VulkanFenceWaitFailed;

    var imageIndex: u32 = undefined;
    var result = c.vkAcquireNextImageKHR(self.device, self.swapChain, std.math.maxInt(u64), self.imageAvailableSemaphores[self.currentFrame], null, &imageIndex);

    if (result == c.VK_ERROR_OUT_OF_DATE_KHR) {
        try self.recreateSwapChain();
        return;
    } else if (result != c.VK_SUCCESS and result != c.VK_SUBOPTIMAL_KHR) return error.VulkanImageAcquisitionFailed;

    try self.updateUniformBuffer(self.currentFrame);

    if (c.vkResetFences(self.device, 1, &self.inFlightFences[self.currentFrame]) != c.VK_SUCCESS) return error.VulkanFenceResetFailed;
    if (c.vkResetCommandBuffer(self.commandBuffers[self.currentFrame], 0) != c.VK_SUCCESS) return error.VulkanCommandBufferResetFailed;
    try self.recordCommandBuffer(self.commandBuffers[self.currentFrame], imageIndex);

    const waitSemaphores = [_]c.VkSemaphore{self.imageAvailableSemaphores[self.currentFrame]};
    const waitStages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

    const signalSemaphores = [_]c.VkSemaphore{self.renderFinishedSemaphores[self.currentFrame]};

    var submitInfo = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &waitSemaphores,
        .pWaitDstStageMask = &waitStages,
        .commandBufferCount = 1,
        .pCommandBuffers = &self.commandBuffers[self.currentFrame],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &signalSemaphores,
        .pNext = null,
    };

    if (c.vkQueueSubmit(self.graphicsQueue, 1, &submitInfo, self.inFlightFences[self.currentFrame]) != c.VK_SUCCESS) return error.VulkanQueueSubmissionFailed;

    const swapChains = [_]c.VkSwapchainKHR{self.swapChain};
    const presentInfo = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signalSemaphores,
        .swapchainCount = 1,
        .pSwapchains = &swapChains,
        .pImageIndices = &imageIndex,
        .pResults = null,
        .pNext = null,
    };

    result = c.vkQueuePresentKHR(self.presentQueue, &presentInfo);

    if (result == c.VK_ERROR_OUT_OF_DATE_KHR or result == c.VK_SUBOPTIMAL_KHR or self.framebufferResized) {
        self.framebufferResized = false;
        try self.recreateSwapChain();
    } else if (result != c.VK_SUCCESS) return error.VulkanQueuePresentationFailed;

    self.currentFrame = (self.currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
}

fn updateUniformBuffer(self: *@This(), currentImage: u32) !void {
    const time: f32 = @as(f32, @floatFromInt((try std.time.Instant.now()).since(self.startTime))) / @as(f32, std.time.ns_per_s);

    var ubo = UniformBufferObject{
        .model = vkm.rotate(vkm.identity, time * std.math.degreesToRadians(90), .{ 0.0, 0.0, 1.0 }),
        .view = vkm.lookAt(.{ 2.0, 2.0, 2.0 }, .{ 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 1.0 }),
        .proj = vkm.perspective(std.math.degreesToRadians(45.0), @as(f32, @floatFromInt(self.swapChainExtent.width)) / @as(f32, @floatFromInt(self.swapChainExtent.height)), 0.1, 10.0),
    };

    ubo.proj[1][1] *= -1.0;

    @memcpy(@as([*]u8, @ptrCast(self.uniformBuffersData[currentImage].?))[0..@intCast(@sizeOf(UniformBufferObject))], std.mem.asBytes(&ubo));
}

fn recordCommandBuffer(self: *@This(), commandBuffer: c.VkCommandBuffer, imageIndex: u32) !void {
    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT,
        .pInheritanceInfo = null,
        .pNext = null,
    };

    if (c.vkBeginCommandBuffer(commandBuffer, &beginInfo) != c.VK_SUCCESS) return error.VulkanCommandBufferBeginFailed;

    const clearColor = [1]c.VkClearValue{
        c.VkClearValue{
            .color = c.VkClearColorValue{
                .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        },
    };

    const renderPassInfo = c.VkRenderPassBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = self.renderPass,
        .framebuffer = self.swapChainFramebuffers[imageIndex],
        .renderArea = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.swapChainExtent,
        },
        .clearValueCount = 1,
        .pClearValues = @as(*const [1]c.VkClearValue, &clearColor),
        .pNext = null,
    };

    c.vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);

    c.vkCmdBindPipeline(commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicsPipeline);

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(self.swapChainExtent.width),
        .height = @floatFromInt(self.swapChainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    c.vkCmdSetViewport(commandBuffer, 0, 1, &viewport);

    const scissor = c.VkRect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = self.swapChainExtent,
    };
    c.vkCmdSetScissor(commandBuffer, 0, 1, &scissor);

    const vertexBuffers = [_]c.VkBuffer{self.vertexBuffer};
    const offsets = [_]c.VkDeviceSize{0};
    c.vkCmdBindVertexBuffers(commandBuffer, 0, 1, &vertexBuffers, &offsets);
    c.vkCmdBindIndexBuffer(commandBuffer, self.indexBuffer, 0, c.VK_INDEX_TYPE_UINT16);

    c.vkCmdBindDescriptorSets(commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipelineLayout, 0, 1, &self.descriptorSets[self.currentFrame], 0, null);

    c.vkCmdDrawIndexed(commandBuffer, @intCast(_indices.len), 1, 0, 0, 0);

    c.vkCmdEndRenderPass(commandBuffer);

    if (c.vkEndCommandBuffer(commandBuffer) != c.VK_SUCCESS) return error.VulkanCommandBufferEndFailed;
}
