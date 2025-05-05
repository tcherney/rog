const std = @import("std");
const engine = @import("engine");
const common = @import("common");

const AsciiGraphics = engine.AsciiGraphics;
const ColorMode = engine.ascii_graphics.ColorMode;

const MoveDirection = enum {
    LEFT,
    RIGHT,
    UP,
    DOWN,
};

pub fn Player(comptime color_type: ColorMode) type {
    return struct {
        x: i32,
        y: i32,
        color: common.Pixel,
        symbol: u8,
        const Self = @This();
        pub const Error = error{} || engine.ascii_graphics.Error;
        pub fn init() Self {
            return .{
                .x = 0,
                .y = 0,
                .color = common.Pixel.init(255, 0, 255, null),
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
        pub fn draw(self: *Self, renderer: *AsciiGraphics(color_type), dest: ?engine.Texture) void {
            renderer.draw_symbol(self.x, self.y, self.symbol, self.color, dest);
        }
        pub fn update(self: *Self, dt: u64) void {
            _ = self;
            _ = dt;
        }
    };
}
