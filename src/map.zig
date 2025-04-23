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
const Point = common.Point(2, usize);

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

    pub fn contains_point(self: *const Room, p: Point) bool {
        return p.x >= self.x and p.x <= self.x + self.width and p.y >= self.y and p.y <= self.y + self.height;
    }
};

pub const BLACK = Pixel.init(0, 0, 0, 255);

pub const DungeonTiles = struct {
    pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(0, 255, 0, null), .bck_color = BLACK };
    pub const WALL: Tile = Tile{ .symbol = '#', .color = Pixel.init(255, 0, 0, null), .bck_color = BLACK };
    pub const VERT_FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(0, 0, 255, null), .bck_color = BLACK };
    pub const VERT_WALL: Tile = Tile{ .symbol = '#', .color = Pixel.init(0, 0, 255, null), .bck_color = BLACK };
    pub const HOR_FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(255, 255, 0, null), .bck_color = BLACK };
    pub const HOR_WALL: Tile = Tile{ .symbol = '#', .color = Pixel.init(255, 255, 0, null), .bck_color = BLACK };
    pub const EMPTY: Tile = Tile{ .symbol = ' ', .color = BLACK, .bck_color = Pixel.init(0, 0, 0, null) };
    pub const START: Tile = Tile{ .symbol = '*', .color = Pixel.init(0, 255, 255, null), .bck_color = BLACK };
    pub const EXIT: Tile = Tile{ .symbol = '$', .color = Pixel.init(0, 255, 0, null), .bck_color = BLACK };
};

pub const ForestTiles = struct {
    pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Pixel.init(0, 255, 0, null), .bck_color = BLACK };
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
        pub fn valid_position(self: *const Self, x: i32, y: i32) bool {
            const x_usize: usize = @intCast(@as(u32, @bitCast(x)));
            const y_usize: usize = @intCast(@as(u32, @bitCast(y)));
            return self.tex.ascii_buffer[y_usize * self.width + x_usize] != TileType.WALL.symbol and self.tex.ascii_buffer[y_usize * self.width + x_usize] != TileType.HOR_WALL.symbol and self.tex.ascii_buffer[y_usize * self.width + x_usize] != TileType.VERT_WALL.symbol;
        }
        pub fn assign_tile(self: *Self, x: usize, y: usize, tile: Tile, overwrite: bool) void {
            if (!overwrite) {
                if (self.tex.ascii_buffer[y * self.width + x] == TileType.FLOOR.symbol) return;
            }
            self.tex.ascii_buffer[y * self.width + x] = tile.symbol;
            self.tex.background_pixel_buffer[y * self.width + x] = tile.bck_color;
            self.tex.pixel_buffer[y * self.width + x] = tile.color;
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
                self.tex.pixel_buffer[i] = TileType.EMPTY.color;
                self.tex.background_pixel_buffer[i] = TileType.EMPTY.bck_color;
                self.tex.ascii_buffer[i] = TileType.EMPTY.symbol;
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
                        self.assign_tile(j, i, room.tiles[indx], true);
                        indx += 1;
                    }
                }
            }
            for (0..self.rooms.items.len) |k| {
                //TODO add corridor connecting the rooms
                if (k < self.rooms.items.len - 1) {
                    //find center of the two rooms
                    const r1 = self.rooms.items[k];
                    const r2 = self.rooms.items[k + 1];
                    const r1_center: Point = .{ .x = r1.x + r1.width / 2, .y = r1.y + r1.height / 2 };
                    const r2_center: Point = .{ .x = r2.x + r2.width / 2, .y = r2.y + r2.height / 2 };
                    self.tex.ascii_buffer[r1_center.y * self.width + r1_center.x] = @intCast(48 + k);
                    self.tex.ascii_buffer[r2_center.y * self.width + r2_center.x] = @intCast(48 + k + 1);
                    var vertical: bool = rand.boolean();
                    if (r1.contains_point(.{ .x = r1.x, .y = r2_center.y })) vertical = false;
                    if (r1.contains_point(.{ .x = r2_center.x, .y = r1.y })) vertical = true;
                    var curr_y: usize = r1_center.y;
                    var curr_x: usize = r1_center.x;
                    if (vertical) {
                        std.debug.print("From room {d} to {d} going veritcal first", .{ k, k + 1 });
                        if (r2_center.y > r1_center.y) {
                            curr_y = r1.y + r1.height - 1;
                            while (curr_y <= r2_center.y) : (curr_y += 1) {
                                self.assign_tile(curr_x, curr_y, TileType.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, TileType.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, TileType.VERT_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, TileType.VERT_WALL, false);
                            curr_y -= 1;
                        } else {
                            curr_y = r1.y;
                            while (curr_y >= r2_center.y) : (curr_y -= 1) {
                                self.assign_tile(curr_x, curr_y, TileType.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, TileType.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, TileType.VERT_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, TileType.VERT_WALL, false);
                            curr_y += 1;
                        }
                        if (r2_center.x > r1_center.x) {
                            curr_x += 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_x += 1;
                            self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                            while (curr_x <= r2.x) : (curr_x += 1) {
                                self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                                self.assign_tile(curr_x, curr_y - 1, TileType.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, TileType.HOR_WALL, false);
                            }
                        } else {
                            curr_x -= 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_x -= 1;
                            self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                            while (curr_x >= r2.x + r2.width - 1) : (curr_x -= 1) {
                                self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                                self.assign_tile(curr_x, curr_y - 1, TileType.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, TileType.HOR_WALL, false);
                            }
                        }
                    } else {
                        std.debug.print("From room {d} to {d} going horizontal first", .{ k, k + 1 });
                        if (r2_center.x > r1_center.x) {
                            curr_x = r1.x + r1.width - 1;
                            while (curr_x <= r2_center.x) : (curr_x += 1) {
                                self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x, curr_y - 1, TileType.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, TileType.HOR_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, TileType.HOR_WALL, false);
                            curr_x -= 1;
                        } else {
                            curr_x = r1.x;
                            while (curr_x >= r2_center.x) : (curr_x -= 1) {
                                self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x, curr_y - 1, TileType.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, TileType.HOR_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, TileType.HOR_WALL, false);
                            curr_x += 1;
                        }
                        if (r2_center.y > r1_center.y) {
                            curr_y += 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_y += 1;
                            self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                            while (curr_y <= r2.y) : (curr_y += 1) {
                                self.assign_tile(curr_x, curr_y, TileType.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, TileType.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, TileType.VERT_WALL, false);
                            }
                        } else {
                            curr_y -= 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_y -= 1;
                            self.assign_tile(curr_x, curr_y, TileType.HOR_FLOOR, false);
                            while (curr_y >= r2.y + r2.height - 1) : (curr_y -= 1) {
                                self.assign_tile(curr_x, curr_y, TileType.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, TileType.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, TileType.VERT_WALL, false);
                            }
                        }
                    }
                }
            }
        }
        pub fn draw(self: *Self, x: i32, y: i32, renderer: *AsciiGraphics(color_type), dest: ?Texture) Error!void {
            try renderer.draw_texture(self.tex, .{ .x = 0, .y = 0, .width = self.tex.width, .height = self.tex.height }, .{ .x = x, .y = y, .width = self.tex.width, .height = self.tex.height }, dest);
        }
    };
}
