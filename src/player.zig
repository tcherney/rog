const std = @import("std");
const map = @import("map.zig");
const engine = @import("engine");
const common = @import("common");

const AsciiRenderer = engine.graphics.AsciiRenderer;
pub const IndexType = map.IndexType;
pub const IndexTypeI = map.IndexTypeI;

const MoveDirection = enum {
    LEFT,
    RIGHT,
    UP,
    DOWN,
};
//TODO why do we have IndexTypeI
pub const Player = struct {
    x: IndexTypeI,
    y: IndexTypeI,
    color: common.Pixel,
    symbol: u8,
    const Self = @This();
    pub const Error = error{} || engine.graphics.Error;
    pub fn init() Self {
        return .{
            .x = 0,
            .y = 0,
            .color = common.Colors.MAGENTA,
            .symbol = '@',
        };
    }
    pub fn move(self: *Self, move_direction: MoveDirection, m: *map.Map) bool {
        var result: bool = true;
        switch (move_direction) {
            .UP => {
                self.y -= 1;
                if (!m.valid_position(self.x, self.y)) {
                    self.y += 1;
                    result = false;
                }
            },
            .DOWN => {
                self.y += 1;
                if (!m.valid_position(self.x, self.y)) {
                    self.y -= 1;
                    result = false;
                }
            },
            .LEFT => {
                self.x -= 1;
                if (!m.valid_position(self.x, self.y)) {
                    self.x += 1;
                    result = false;
                }
            },
            .RIGHT => {
                self.x += 1;
                if (!m.valid_position(self.x, self.y)) {
                    self.x -= 1;
                    result = false;
                }
            },
        }
        return result;
    }
    pub fn draw(self: *Self, renderer: *AsciiRenderer, dest: ?engine.Texture) void {
        renderer.draw_symbol(@intCast(self.x), @intCast(self.y), self.symbol, self.color, dest);
    }
    pub fn update(self: *Self, dt: u64) void {
        _ = self;
        _ = dt;
    }
};
