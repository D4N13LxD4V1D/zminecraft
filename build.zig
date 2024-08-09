const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zminecraft",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ecs = b.addModule("ecs", .{ .root_source_file = b.path("src/ecs/root.zig"), .target = target, .optimize = optimize });
    ecs.linkSystemLibrary("sqlite3", .{ .preferred_link_mode = .static });
    exe.root_module.addImport("ecs", ecs);

    const renderer = b.addModule("renderer", .{ .root_source_file = b.path("src/renderer/root.zig"), .target = target, .optimize = optimize });
    renderer.linkSystemLibrary(if (target.result.os.tag == .windows) "vulkan-1" else "vulkan", .{ .preferred_link_mode = .static });
    renderer.linkSystemLibrary("glfw3", .{ .preferred_link_mode = .static });

    try addShader(b, renderer, "shader.vert", "vert.spv");
    try addShader(b, renderer, "shader.frag", "frag.spv");

    renderer.addIncludePath(b.path("include"));
    renderer.addCSourceFile(.{ .file = b.path("lib/stb_image.c") });
    renderer.addAnonymousImport("textures/texture.jpg", .{ .root_source_file = b.path("textures/texture.jpg") });

    exe.root_module.addImport("renderer", renderer);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addShader(b: *std.Build, module: *std.Build.Module, comptime in_file: []const u8, comptime out_file: []const u8) !void {
    const run_cmd = b.addSystemCommand(&.{"glslangValidator"});
    run_cmd.addArg("-V");
    run_cmd.addArg("-o");
    const output = run_cmd.addOutputFileArg("shaders/" ++ out_file);
    run_cmd.addFileArg(b.path("shaders/" ++ in_file));

    module.addAnonymousImport(out_file, .{ .root_source_file = output });
}
