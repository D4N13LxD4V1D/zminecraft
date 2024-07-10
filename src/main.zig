const std = @import("std");
const ecs = @import("ecs");
const renderer = @import("renderer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak detected\n");

    try renderer.run(gpa.allocator());
}
