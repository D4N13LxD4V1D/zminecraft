const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig").c;

const WIDTH = 800;
const HEIGHT = 600;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
const deviceExtensions = [_][*:0]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

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
renderPass: c.VkRenderPass = undefined,
pipelineLayout: c.VkPipelineLayout = undefined,
graphicsPipeline: c.VkPipeline = undefined,

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

pub fn run(allocator: std.mem.Allocator) !void {
    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);

    const window = c.glfwCreateWindow(WIDTH, HEIGHT, "zminecraft", null, null) orelse return error.GlfwWindowCreationFailed;
    defer c.glfwDestroyWindow(window);

    var self: @This() = .{};
    try self.initVulkan(allocator, window);

    c.glfwMakeContextCurrent(window);
    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    try self.cleanup(allocator);
}

fn initVulkan(self: *@This(), allocator: std.mem.Allocator, window: *c.GLFWwindow) !void {
    try self.createInstance(allocator);
    try self.setupDebugMessenger();
    try self.createSurface(window);
    try self.pickPhysicalDevice(allocator);
    try self.createLogicalDevice(allocator);
    try self.createSwapChain(allocator, window);
    try self.createImageViews(allocator);
    try self.createRenderPass();
    try self.createGraphicsPipeline();
}

fn cleanup(self: *@This(), allocator: std.mem.Allocator) !void {
    c.vkDestroyPipeline(self.device, self.graphicsPipeline, null);
    c.vkDestroyPipelineLayout(self.device, self.pipelineLayout, null);
    c.vkDestroyRenderPass(self.device, self.renderPass, null);

    for (self.swapChainImageViews) |imageView|
        c.vkDestroyImageView(self.device, imageView, null);
    allocator.free(self.swapChainImageViews);

    c.vkDestroySwapchainKHR(self.device, self.swapChain, null);
    allocator.free(self.swapChainImages);

    c.vkDestroySurfaceKHR(self.instance, self.surface, null);
    c.vkDestroyDevice(self.device, null);

    if (enableValidationLayers)
        DestroyDebugUtilsMessengerEXT(self.instance, self.debugMessenger, null);

    c.vkDestroyInstance(self.instance, null);
}

fn createInstance(self: *@This(), allocator: std.mem.Allocator) !void {
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

    if (c.vkCreateInstance(&createInfo, null, &self.instance) != c.VK_SUCCESS) return error.VulkanInstanceCreationFailed;
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
    errdefer extensions.deinit();

    try extensions.appendSlice(glfwExtensions[0..glfwExtensionCount]);

    if (builtin.os.tag == .macos)
        try extensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);

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

    std.log.info("Validation layer: {s}\n", .{pCallbackData.*.pMessage});

    return c.VK_FALSE;
}

fn CreateDebugUtilsMessengerEXT(instance: c.VkInstance, pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT, pAllocator: ?*const c.VkAllocationCallbacks, pDebugMessenger: *c.VkDebugUtilsMessengerEXT) c.VkResult {
    const func: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT") orelse return c.VK_ERROR_EXTENSION_NOT_PRESENT);
    return func.?(instance, pCreateInfo, pAllocator, pDebugMessenger);
}

fn DestroyDebugUtilsMessengerEXT(instance: c.VkInstance, debugMessenger: c.VkDebugUtilsMessengerEXT, pAllocator: ?*const c.VkAllocationCallbacks) void {
    const func: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT") orelse unreachable);
    return func.?(instance, debugMessenger, pAllocator);
}

fn createSurface(self: *@This(), window: *c.GLFWwindow) !void {
    if (c.glfwCreateWindowSurface(self.instance, window, null, &self.surface) != c.VK_SUCCESS) return error.FailedToCreateWindowSurface;
}

fn pickPhysicalDevice(self: *@This(), allocator: std.mem.Allocator) !void {
    var physicalDeviceCount: u32 = undefined;
    if (c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, null) != c.VK_SUCCESS) return error.VulkanPhysicalDeviceEnumerationFailed;
    if (physicalDeviceCount == 0) return error.VulkanNoPhysicalDevicesFound;

    const physicalDevices = try allocator.alloc(c.VkPhysicalDevice, physicalDeviceCount);
    defer allocator.free(physicalDevices);
    if (c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, physicalDevices.ptr) != c.VK_SUCCESS) return error.VulkanPhysicalDeviceEnumerationFailed;

    self.physicalDevice = for (physicalDevices) |device| {
        if (try self.isDeviceSuitable(allocator, device)) {
            break device;
        }
    } else return error.VulkanNoSuitablePhysicalDeviceFound;
}

fn isDeviceSuitable(self: @This(), allocator: std.mem.Allocator, device: c.VkPhysicalDevice) !bool {
    const indices = try self.findQueueFamilies(allocator, device);

    const extensionsSupported = try checkDeviceExtensionSupport(allocator, device);

    const swapChainAdequate = if (extensionsSupported) block: {
        var swapChainSupport = try self.querySwapChainSupport(allocator, device);
        defer swapChainSupport.deinit();
        break :block swapChainSupport.formats.items.len != 0 and swapChainSupport.presentModes.items.len != 0;
    } else false;

    return indices.isComplete() and extensionsSupported and swapChainAdequate;
}

fn findQueueFamilies(self: @This(), allocator: std.mem.Allocator, device: c.VkPhysicalDevice) !QueueFamilyIndices {
    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    defer allocator.free(queueFamilies);
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

fn checkDeviceExtensionSupport(allocator: std.mem.Allocator, device: c.VkPhysicalDevice) !bool {
    var extensionCount: u32 = undefined;
    if (c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, null) != c.VK_SUCCESS) return error.VulkanDeviceExtensionEnumerationFailed;

    const availableExtensions = try allocator.alloc(c.VkExtensionProperties, extensionCount);
    defer allocator.free(availableExtensions);

    if (c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, availableExtensions.ptr) != c.VK_SUCCESS) return error.VulkanDeviceExtensionEnumerationFailed;

    var requiredExtensions = std.HashMap(
        [*:0]const u8,
        void,
        struct {
            pub fn hash(_: @This(), self: [*:0]const u8) u64 {
                var h: u32 = 2166136261;
                var i: usize = 0;
                while (self[i] != 0) : (i += 1) {
                    h ^= self[i];
                    h *%= 16777619;
                }
                return h;
            }

            pub fn eql(_: @This(), self: [*:0]const u8, other: [*:0]const u8) bool {
                return std.mem.eql(u8, std.mem.span(self), std.mem.span(other));
            }
        },
        std.hash_map.default_max_load_percentage,
    ).init(allocator);
    defer requiredExtensions.deinit();

    for (deviceExtensions) |extension|
        try requiredExtensions.put(extension, {});

    for (availableExtensions) |extension|
        _ = requiredExtensions.remove(@ptrCast(&extension.extensionName));

    return requiredExtensions.count() == 0;
}

fn querySwapChainSupport(self: @This(), allocator: std.mem.Allocator, device: c.VkPhysicalDevice) !SwapChainSupportDetails {
    var details = SwapChainSupportDetails.init(allocator);
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

fn createLogicalDevice(self: *@This(), allocator: std.mem.Allocator) !void {
    const indices = try self.findQueueFamilies(allocator, self.physicalDevice);

    var queueCreateInfos = std.ArrayList(c.VkDeviceQueueCreateInfo).init(allocator);
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

    const deviceFeatures = c.VkPhysicalDeviceFeatures{};

    const createInfo = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = @intCast(queueCreateInfos.items.len),
        .pQueueCreateInfos = queueCreateInfos.items.ptr,
        .enabledExtensionCount = @intCast(deviceExtensions.len),
        .ppEnabledExtensionNames = &deviceExtensions,
        .pEnabledFeatures = &deviceFeatures,
    };

    if (c.vkCreateDevice(self.physicalDevice, &createInfo, null, &self.device) != c.VK_SUCCESS) return error.VulkanLogicalDeviceCreationFailed;

    c.vkGetDeviceQueue(self.device, indices.graphicsFamily.?, 0, &self.graphicsQueue);
    c.vkGetDeviceQueue(self.device, indices.presentFamily.?, 0, &self.presentQueue);
}

fn createSwapChain(self: *@This(), allocator: std.mem.Allocator, window: *c.GLFWwindow) !void {
    var swapChainSupport = try self.querySwapChainSupport(allocator, self.physicalDevice);
    defer swapChainSupport.deinit();

    const surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats.items);
    const presentMode = chooseSwapPresentMode(swapChainSupport.presentModes.items);
    const extent = chooseSwapExtent(window, swapChainSupport.capabilities);

    var imageCount = swapChainSupport.capabilities.minImageCount + 1;
    if (swapChainSupport.capabilities.maxImageCount > 0 and imageCount > swapChainSupport.capabilities.maxImageCount)
        imageCount = swapChainSupport.capabilities.maxImageCount;

    const indices = try self.findQueueFamilies(allocator, self.physicalDevice);
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

    self.swapChainImages = try allocator.alloc(c.VkImage, imageCount);

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

fn createImageViews(self: *@This(), allocator: std.mem.Allocator) !void {
    self.swapChainImageViews = try allocator.alloc(c.VkImageView, self.swapChainImages.len);
    errdefer allocator.free(self.swapChainImageViews);

    for (self.swapChainImages, 0..) |swapChainImage, i| {
        const createInfo = c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = swapChainImage,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = self.swapChainImageFormat,
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

        if (c.vkCreateImageView(self.device, &createInfo, null, &self.swapChainImageViews[i]) != c.VK_SUCCESS) return error.VulkanImageViewCreationFailed;
    }
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

    const renderPassInfo = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &colorAttachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 0,
        .pDependencies = null,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateRenderPass(self.device, &renderPassInfo, null, &self.renderPass) != c.VK_SUCCESS) return error.VulkanRenderPassCreationFailed;
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

    const vertexInputInfo = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
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

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @intCast(self.swapChainExtent.width),
        .height = @intCast(self.swapChainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    const scissor = c.VkRect2D{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = self.swapChainExtent,
    };

    const viewportState = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
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
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
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
        .setLayoutCount = 0,
        .pSetLayouts = null,
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
        .basePipelineHandle = c.VK_NULL_HANDLE,
        .basePipelineIndex = -1,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateGraphicsPipelines(self.device, c.VK_NULL_HANDLE, 1, &pipelineInfo, null, &self.graphicsPipeline) != c.VK_SUCCESS) return error.VulkanGraphicsPipelineCreationFailed;
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
