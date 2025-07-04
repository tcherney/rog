const std = @import("std");
const engine = @import("engine");
const common = @import("common");

const AsciiRenderer = engine.graphics.AsciiRenderer;

const MoveDirection = enum {
    LEFT,
    RIGHT,
    UP,
    DOWN,
};
//TODO why do we have i32
pub const Player = struct {
    x: i32,
    y: i32,
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
    pub fn move(self: *Self, move_direction: MoveDirection, map: anytype) bool {
        var result: bool = true;
        switch (move_direction) {
            .UP => {
                self.y -= 1;
                if (!map.valid_position(self.x, self.y)) {
                    self.y += 1;
                    result = false;
                }
            },
            .DOWN => {
                self.y += 1;
                if (!map.valid_position(self.x, self.y)) {
                    self.y -= 1;
                    result = false;
                }
            },
            .LEFT => {
                self.x -= 1;
                if (!map.valid_position(self.x, self.y)) {
                    self.x += 1;
                    result = false;
                }
            },
            .RIGHT => {
                self.x += 1;
                if (!map.valid_position(self.x, self.y)) {
                    self.x -= 1;
                    result = false;
                }
            },
        }
        return result;
    }
    pub fn draw(self: *Self, renderer: *AsciiRenderer, dest: ?engine.Texture) void {
        renderer.draw_symbol(self.x, self.y, self.symbol, self.color, dest);
    }
    pub fn update(self: *Self, dt: u64) void {
        _ = self;
        _ = dt;
    }
};
