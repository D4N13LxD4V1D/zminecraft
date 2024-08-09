pub const c = @cImport({
    @cInclude("stb_image.h");
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});
