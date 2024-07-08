const ecs = @import("ecs");
const renderer = @import("renderer");

pub fn main() !void {
    try ecs.init().run();
}
