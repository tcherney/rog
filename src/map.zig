const std = @import("std");
const engine = @import("engine");
const common = @import("common");
pub const MapType = enum {
    DUNGEON,
    FOREST,
};
const Allocator = std.mem.Allocator;
const Pixel = common.Pixel;
const AsciiGraphics = engine.AsciiGraphics;
const ColorMode = engine.ascii_graphics.ColorMode;
const Texture = engine.Texture;
const Rectangle = common.Rectangle;

pub fn Map(comptime map_type: MapType, comptime color_type: ColorMode) type {
    return struct {
        allocator: Allocator,
        tiles: Texture = undefined,
        pub const Tile = struct {
            symbol: u8,
            color: Pixel,
            bck_color: Pixel,
        };
        pub const TileType = switch (map_type) {
            .DUNGEON => struct {
                pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(0, 255, 0, null), .bck_color = Pixel.init(0, 0, 0, null) };
                pub const WALL: Tile = Tile{ .symbol = '#', .color = Pixel.init(255, 0, 0, null), .bck_color = Pixel.init(0, 0, 0, null) };
            },
            .FOREST => struct {
                pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(0, 255, 0, null), .bck_color = Pixel.init(0, 0, 0, null) };
            },
        };
        const Self = @This();
        pub const Error = error{} || engine.ascii_graphics.Error || Texture.Error;
        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
            };
        }
        pub fn deinit(self: *Self) void {
            self.tiles.deinit();
        }
        //TODO add more parameters
        //TODO add generation
        pub fn generate(self: *Self, width: usize, height: usize) Error!void {
            self.tiles = Texture.init(self.allocator);
            self.tiles.is_ascii = true;
            try self.tiles.rect(@intCast(width), @intCast(height), 0, 0, 0, 255);
            for (0..self.tiles.pixel_buffer.len) |i| {
                self.tiles.pixel_buffer[i] = TileType.FLOOR.color;
                self.tiles.background_pixel_buffer[i] = TileType.FLOOR.bck_color;
                self.tiles.ascii_buffer[i] = TileType.FLOOR.symbol;
            }
        }
        pub fn draw(self: *Self, x: i32, y: i32, renderer: *AsciiGraphics(color_type), dest: ?Texture) Error!void {
            try renderer.draw_texture(self.tiles, .{ .x = 0, .y = 0, .width = self.tiles.width, .height = self.tiles.height }, .{ .x = x, .y = y, .width = self.tiles.width, .height = self.tiles.height }, dest);
        }
    };
}
