const engine = @import("engine.zig");
const assets = @import("assets/assets.zig");

pub fn main() !void {
    _ = assets;
    try engine.run();
}
