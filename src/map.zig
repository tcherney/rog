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
const rand = std.crypto.random;

pub const Tile = struct {
    symbol: u8,
    color: Pixel,
    bck_color: Pixel,
};

pub const Room = struct {
    tiles: []Tile = undefined,
    allocator: Allocator,
    height: usize = undefined,
    width: usize = undefined,
    x: usize = undefined,
    y: usize = undefined,
    pub const Error = error{} || Allocator.Error;
    pub fn init(allocator: Allocator) Room {
        return Room{
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *Room) void {
        self.allocator.free(self.tiles);
    }
    pub fn build_room(self: *Room, map_width: usize, map_height: usize, size: usize) Error!void {
        const lower_bounds = @max(4, size);
        self.width = rand.intRangeAtMost(usize, 3, lower_bounds);
        self.height = rand.intRangeAtMost(usize, 3, lower_bounds);
        self.x = rand.intRangeAtMost(usize, 0, map_width - self.width);
        self.y = rand.intRangeAtMost(usize, 0, map_height - self.height);
        std.debug.print("Building new room at x: {d},y: {d} with width: {d} and height: {d}\n", .{ self.x, self.y, self.width, self.height });
        self.tiles = try self.allocator.alloc(Tile, self.width * self.height);
        for (0..self.height) |i| {
            for (0..self.width) |j| {
                if (i == 0 or j == 0 or (i == self.height - 1 or j == self.width - 1)) {
                    self.tiles[i * self.width + j] = DungeonTiles.WALL;
                } else {
                    self.tiles[i * self.width + j] = DungeonTiles.FLOOR;
                }
            }
        }
    }

    pub fn has_conflict(self: *Room, other: *Room) bool {
        return self.x + self.width >= other.x and self.x <= other.x + other.width and self.y + self.height >= other.y and self.y <= other.y + other.height;
    }
};

pub const DungeonTiles = struct {
    pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(0, 255, 0, null), .bck_color = Pixel.init(0, 0, 0, null) };
    pub const WALL: Tile = Tile{ .symbol = '#', .color = Pixel.init(255, 0, 0, null), .bck_color = Pixel.init(0, 0, 0, null) };
};

pub const ForestTiles = struct {
    pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(0, 255, 0, null), .bck_color = Pixel.init(0, 0, 0, null) };
};

pub fn Map(comptime map_type: MapType, comptime color_type: ColorMode) type {
    return struct {
        allocator: Allocator,
        tex: Texture = undefined,
        width: usize = undefined,
        height: usize = undefined,
        rooms: std.ArrayList(Room),
        pub const TileType = switch (map_type) {
            .DUNGEON => DungeonTiles,
            .FOREST => ForestTiles,
        };
        const Self = @This();
        pub const Error = error{} || engine.ascii_graphics.Error || Texture.Error;
        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .rooms = std.ArrayList(Room).init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            self.tex.deinit();
            for (0..self.rooms.items.len) |i| {
                self.rooms.items[i].deinit();
            }
            self.rooms.deinit();
        }
        //TODO add more parameters
        //TODO add generation
        pub fn generate(self: *Self, width: usize, height: usize, num_objects: usize) Error!void {
            self.tex = Texture.init(self.allocator);
            self.tex.is_ascii = true;
            self.width = width;
            self.height = height;
            try self.tex.rect(@intCast(width), @intCast(height), 0, 0, 0, 255);
            for (0..self.tex.pixel_buffer.len) |i| {
                self.tex.pixel_buffer[i] = TileType.FLOOR.color;
                self.tex.background_pixel_buffer[i] = TileType.FLOOR.bck_color;
                self.tex.ascii_buffer[i] = TileType.FLOOR.symbol;
            }
            var cur_object: usize = 0;
            const MAX_ATTEMPTS = 20;
            var attempt: usize = 0;
            outer: while (cur_object < num_objects) {
                if (attempt >= MAX_ATTEMPTS) break;
                switch (map_type) {
                    .DUNGEON => {
                        var new_room = Room.init(self.allocator);
                        try new_room.build_room(self.width, self.height, 8);
                        if (self.rooms.items.len == 0) {
                            try self.rooms.append(new_room);
                            cur_object += 1;
                        } else {
                            for (0..self.rooms.items.len) |i| {
                                if (self.rooms.items[i].has_conflict(&new_room)) {
                                    attempt += 1;
                                    new_room.deinit();
                                    continue :outer;
                                }
                            }
                            try self.rooms.append(new_room);
                            cur_object += 1;
                            attempt = 0;
                        }
                    },
                    .FOREST => {
                        unreachable;
                    },
                }
            }
            for (0..self.rooms.items.len) |k| {
                const room = self.rooms.items[k];
                var indx: usize = 0;
                for (room.y..room.y + room.height) |i| {
                    for (room.x..room.x + room.width) |j| {
                        self.tex.ascii_buffer[i * self.width + j] = room.tiles[indx].symbol;
                        self.tex.background_pixel_buffer[i * self.width + j] = room.tiles[indx].bck_color;
                        self.tex.pixel_buffer[i * self.width + j] = room.tiles[indx].color;
                        indx += 1;
                    }
                }
                //TODO add corridor connecting the rooms
            }
        }
        pub fn draw(self: *Self, x: i32, y: i32, renderer: *AsciiGraphics(color_type), dest: ?Texture) Error!void {
            try renderer.draw_texture(self.tex, .{ .x = 0, .y = 0, .width = self.tex.width, .height = self.tex.height }, .{ .x = x, .y = y, .width = self.tex.width, .height = self.tex.height }, dest);
        }
    };
}
