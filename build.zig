const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ecs = b.addModule("ecs", .{ .root_source_file = b.path("src/ecs/root.zig"), .target = target, .optimize = optimize });
    ecs.linkSystemLibrary("sqlite3", .{ .preferred_link_mode = .static });

    const renderer = b.addModule("renderer", .{ .root_source_file = b.path("src/renderer/root.zig"), .target = target, .optimize = optimize });
    renderer.linkSystemLibrary("vulkan", .{ .preferred_link_mode = .static });
    renderer.linkSystemLibrary("glfw3", .{ .preferred_link_mode = .static });

    const exe = b.addExecutable(.{
        .name = "zminecraft",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("ecs", ecs);
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
