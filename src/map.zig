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
const Colors = common.Colors;
const TEXT_COLOR = Colors.WHITE;

pub const MapExit = struct {
    map_indx: usize = undefined,
    map_col_indx: usize = undefined,
    chunk_info: MapTile,
    ext_map_indx: usize = undefined,
    ext_map_col_indx: usize = undefined,
    ext_chunk_info: MapTile = undefined,
    connected: bool = false,
    pub fn connect_chunks(self: *MapExit, other: *MapExit, self_map_indx: usize, other_map_indx: usize, self_map_col_indx: usize, other_map_col_indx: usize) void {
        self.map_indx = self_map_indx;
        self.ext_map_indx = other_map_indx;
        other.map_indx = other_map_indx;
        other.ext_map_indx = self_map_indx;

        self.map_col_indx = self_map_col_indx;
        self.ext_map_col_indx = other_map_col_indx;
        other.map_col_indx = other_map_col_indx;
        other.ext_map_col_indx = self_map_col_indx;

        self.ext_chunk_info = other.chunk_info;
        other.ext_chunk_info = self.chunk_info;

        self.connected = true;
        other.connected = true;
    }
};

pub const Tile = struct {
    symbol: u8,
    color: Pixel,
    bck_color: Pixel,
};

pub const MapChunk = struct {
    tiles: []Tile = undefined,
    allocator: Allocator,
    height: usize = undefined,
    width: usize = undefined,
    x: usize = undefined,
    y: usize = undefined,
    pub const Error = error{} || Allocator.Error;
    pub fn init(allocator: Allocator) MapChunk {
        return MapChunk{
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *MapChunk) void {
        self.allocator.free(self.tiles);
    }
    //TODO add methods for different type of chunks
    pub fn build_room(self: *MapChunk, map_width: usize, map_height: usize, size: usize) Error!void {
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
    //TODO forest chunk generation
    pub fn build_forest_chunk(self: *MapChunk, width: usize, height: usize, x: usize, y: usize) Error!void {
        self.width = width;
        self.height = height;
        self.x = x;
        self.y = y;
        self.tiles = try self.allocator.alloc(Tile, self.width * self.height);
        for (0..self.height) |i| {
            for (0..self.width) |j| {
                self.tiles[i * self.width + j] = ForestTiles.FLOOR;
            }
        }
        //TODO add water,rock,trees and other objects
    }

    pub fn has_conflict(self: *MapChunk, other: *MapChunk) bool {
        return self.x + self.width >= other.x and self.x <= other.x + other.width and self.y + self.height >= other.y and self.y <= other.y + other.height;
    }

    pub fn contains_point(self: *const MapChunk, p: Point) bool {
        return p.x >= self.x and p.x <= self.x + self.width and p.y >= self.y and p.y <= self.y + self.height;
    }
};

//TODO may want to change how we do this to make it less cumbersome
pub const DungeonTiles = struct {
    pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Colors.GREEN, .bck_color = Colors.BLACK };
    pub const WALL: Tile = Tile{ .symbol = '#', .color = Colors.RED, .bck_color = Colors.BLACK };
    pub const VERT_FLOOR: Tile = Tile{ .symbol = '.', .color = Colors.BLUE, .bck_color = Colors.BLACK };
    pub const VERT_WALL: Tile = Tile{ .symbol = '#', .color = Colors.BLUE, .bck_color = Colors.BLACK };
    pub const HOR_FLOOR: Tile = Tile{ .symbol = '.', .color = Colors.YELLOW, .bck_color = Colors.BLACK };
    pub const HOR_WALL: Tile = Tile{ .symbol = '#', .color = Colors.YELLOW, .bck_color = Colors.BLACK };
    pub const EMPTY: Tile = Tile{ .symbol = ' ', .color = Colors.BLACK, .bck_color = Colors.BLACK };
    pub const START: Tile = Tile{ .symbol = '*', .color = Colors.CYAN, .bck_color = Colors.BLACK };
    pub const EXIT: Tile = Tile{ .symbol = '$', .color = Colors.MAGENTA, .bck_color = Colors.BLACK };
};

pub const ForestTiles = struct {
    pub const FLOOR: Tile = Tile{ .symbol = '.', .color = Colors.GREEN, .bck_color = Colors.BLACK };
    pub const EMPTY: Tile = Tile{ .symbol = ' ', .color = Colors.BLACK, .bck_color = Colors.BLACK };
    pub const START: Tile = Tile{ .symbol = '*', .color = Colors.CYAN, .bck_color = Colors.BLACK };
    pub const EXIT: Tile = Tile{ .symbol = '$', .color = Colors.MAGENTA, .bck_color = Colors.BLACK };
    pub const TREE: Tile = Tile{ .symbol = 'T', .color = Colors.WENGE, .bck_color = Colors.BLACK };
    pub const WATER: Tile = Tile{ .symbol = '~', .color = Colors.CERULEAN, .bck_color = Colors.BLACK };
    pub const ROCK: Tile = Tile{ .symbol = 'o', .color = Colors.STONE, .bck_color = Colors.BLACK };
    pub const VERT_ROAD: Tile = Tile{ .symbol = '|', .color = Colors.BEAVER, .bck_color = Colors.BLACK };
    pub const HOR_ROAD: Tile = Tile{ .symbol = '-', .color = Colors.BEAVER, .bck_color = Colors.BLACK };
};

pub const MapTile = struct {
    tile: Tile,
    x: usize,
    y: usize,
};

pub fn Map(comptime color_type: ColorMode) type {
    return struct {
        allocator: Allocator,
        tex: Texture = undefined,
        width: usize = undefined,
        height: usize = undefined,
        chunks: std.ArrayList(MapChunk),
        start_chunks: std.ArrayList(MapExit) = undefined,
        exit_chunks: std.ArrayList(MapExit) = undefined,
        map_type: MapType = undefined,
        name: []u8 = undefined,

        const Self = @This();
        pub const Error = error{} || engine.ascii_graphics.Error || Texture.Error;
        pub fn init(allocator: Allocator, map_type: MapType) Self {
            return Self{
                .allocator = allocator,
                .map_type = map_type,
                .chunks = std.ArrayList(MapChunk).init(allocator),
                .start_chunks = std.ArrayList(MapExit).init(allocator),
                .exit_chunks = std.ArrayList(MapExit).init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            self.tex.deinit();
            for (0..self.chunks.items.len) |i| {
                self.chunks.items[i].deinit();
            }
            self.chunks.deinit();
            self.allocator.free(self.name);
            self.start_chunks.deinit();
            self.exit_chunks.deinit();
        }
        // pub fn chunk_to_map_coord(self: *const Self, chunk_id: usize, x: usize, y: usize) Point {
        //     return .{
        //         .x = self.chunks.items[chunk_id].x + x,
        //         .y = self.chunks.items[chunk_id].y + y,
        //     };
        // }

        // pub fn start_map_coord(self: *const Self) Point {
        //     const start = self.start_chunks.items[0];
        //     return self.chunk_to_map_coord(start.chunk_indx, start.chunk_info.x, start.chunk_info.y);
        // }

        // pub fn exit_map_coord(self: *const Self) Point {
        //     const exit = self.exit_chunks.items[0];
        //     return self.chunk_to_map_coord(exit.chunk_indx, exit.chunk_info.x, exit.chunk_info.y);
        // }

        fn _valid_position(self: *const Self, x: i32, y: i32, TileType: type) bool {
            const x_usize: usize = @intCast(@as(u32, @bitCast(x)));
            const y_usize: usize = @intCast(@as(u32, @bitCast(y)));
            const tile_symbol = self.tex.ascii_buffer[y_usize * self.width + x_usize];
            if (TileType == ForestTiles) {
                return tile_symbol != TileType.TREE.symbol and tile_symbol != TileType.ROCK.symbol and tile_symbol != TileType.WATER.symbol;
            } else if (TileType == DungeonTiles) {
                return tile_symbol != TileType.WALL.symbol and tile_symbol != TileType.HOR_WALL.symbol and tile_symbol != TileType.VERT_WALL.symbol;
            }
        }

        pub fn valid_position(self: *const Self, x: i32, y: i32) bool {
            switch (self.map_type) {
                .DUNGEON => return self._valid_position(x, y, DungeonTiles),
                .FOREST => return self._valid_position(x, y, ForestTiles),
            }
        }

        fn _at_tile(self: *const Self, x: i32, y: i32, symbol: u8) bool {
            const x_usize: usize = @intCast(@as(u32, @bitCast(x)));
            const y_usize: usize = @intCast(@as(u32, @bitCast(y)));
            return self.tex.ascii_buffer[y_usize * self.width + x_usize] == symbol;
        }

        pub fn at_exit(self: *const Self, x: i32, y: i32) bool {
            switch (self.map_type) {
                .DUNGEON => return self._at_tile(x, y, DungeonTiles.EXIT.symbol),
                .FOREST => return self._at_tile(x, y, ForestTiles.EXIT.symbol),
            }
        }

        pub fn at_start(self: *const Self, x: i32, y: i32) bool {
            switch (self.map_type) {
                .DUNGEON => return self._at_tile(x, y, DungeonTiles.START.symbol),
                .FOREST => return self._at_tile(x, y, ForestTiles.START.symbol),
            }
        }

        fn _assign_tile(self: *Self, x: usize, y: usize, tile: Tile, overwrite: bool, TileType: type) void {
            if (!overwrite) {
                if (self.tex.ascii_buffer[y * self.width + x] == TileType.FLOOR.symbol) return;
            }
            self.tex.ascii_buffer[y * self.width + x] = tile.symbol;
            self.tex.background_pixel_buffer[y * self.width + x] = tile.bck_color;
            self.tex.pixel_buffer[y * self.width + x] = tile.color;
        }

        pub fn assign_tile(self: *Self, x: usize, y: usize, tile: Tile, overwrite: bool) void {
            switch (self.map_type) {
                .DUNGEON => self._assign_tile(x, y, tile, overwrite, DungeonTiles),
                .FOREST => self._assign_tile(x, y, tile, overwrite, ForestTiles),
            }
        }

        fn _generate_forest(self: *Self, width: usize, height: usize) Error!void {
            self.tex = Texture.init(self.allocator);
            self.tex.is_ascii = true;
            self.width = width;
            self.height = height;
            try self.tex.rect(@intCast(width), @intCast(height), 0, 0, 0, 255);
            for (0..self.tex.pixel_buffer.len) |i| {
                self.tex.pixel_buffer[i] = ForestTiles.EMPTY.color;
                self.tex.background_pixel_buffer[i] = ForestTiles.EMPTY.bck_color;
                self.tex.ascii_buffer[i] = ForestTiles.EMPTY.symbol;
            }
            var lower_bounds_width: usize = 3;
            var lower_bounds_height: usize = 3;
            std.debug.print("\nWorld width: {d}\n", .{width});
            std.debug.print("\nWorld height: {d}\n", .{height});
            while (self.width % lower_bounds_width != 0) lower_bounds_width += 1;
            while (self.height % lower_bounds_height != 0) lower_bounds_height += 1;
            std.debug.print("lower width: {d}\n", .{lower_bounds_width});
            std.debug.print("lower height: {d}\n", .{lower_bounds_height});
            const chunk_width = self.width / lower_bounds_width;
            const chunk_height = self.height / lower_bounds_height;
            std.debug.print("chunk width: {d}\n", .{chunk_width});
            std.debug.print("chunk height: {d}\n", .{chunk_height});
            const num_chunks = chunk_width * chunk_height;
            for (0..num_chunks) |i| {
                var new_chunk = MapChunk.init(self.allocator);
                const x = (i % chunk_width) * lower_bounds_width;
                const y = (i / chunk_width) * lower_bounds_height;
                try new_chunk.build_forest_chunk(lower_bounds_width, lower_bounds_height, x, y);
                try self.chunks.append(new_chunk);
            }
            for (0..self.chunks.items.len) |k| {
                const chunk = self.chunks.items[k];
                var indx: usize = 0;
                for (chunk.y..chunk.y + chunk.height) |i| {
                    for (chunk.x..chunk.x + chunk.width) |j| {
                        self.assign_tile(j, i, chunk.tiles[indx], true);
                        indx += 1;
                    }
                }
            }

            for (0..self.chunks.items.len) |k| {
                const road_probability = rand.intRangeAtMost(usize, 1, 20);
                if (road_probability != 1) continue;
                if (k < self.chunks.items.len) {
                    //find center of the two rooms
                    const r1 = self.chunks.items[k];
                    var r2_indx: usize = rand.intRangeAtMost(usize, 0, self.chunks.items.len - 1);
                    while (r2_indx == k) r2_indx = rand.intRangeAtMost(usize, 0, self.chunks.items.len - 1);
                    const r2 = self.chunks.items[r2_indx];
                    const r1_center: Point = .{ .x = r1.x + r1.width / 2, .y = r1.y + r1.height / 2 };
                    const r2_center: Point = .{ .x = r2.x + r2.width / 2, .y = r2.y + r2.height / 2 };

                    var vertical: bool = rand.boolean();
                    if (r1.contains_point(.{ .x = r1.x, .y = r2_center.y })) vertical = false;
                    if (r1.contains_point(.{ .x = r2_center.x, .y = r1.y })) vertical = true;
                    var curr_y: usize = r1_center.y;
                    var curr_x: usize = r1_center.x;
                    if (vertical) {
                        std.debug.print("From room {d} to {d} going vertical first", .{ k, k + 1 });
                        if (r2_center.y > r1_center.y) {
                            curr_y = r1.y + r1.height - 1;
                            while (curr_y <= r2_center.y) : (curr_y += 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.VERT_ROAD, true);
                            }
                            curr_y -= 1;
                        } else {
                            curr_y = r1.y;
                            while (curr_y >= r2_center.y) : (curr_y -= 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.VERT_ROAD, true);
                            }
                            curr_y += 1;
                        }
                        if (r2_center.x > r1_center.x) {
                            curr_x += 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_x += 1;
                            self.assign_tile(curr_x, curr_y, ForestTiles.HOR_ROAD, true);
                            while (curr_x <= r2.x) : (curr_x += 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.HOR_ROAD, true);
                            }
                        } else {
                            curr_x -= 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_x -= 1;
                            self.assign_tile(curr_x, curr_y, ForestTiles.HOR_ROAD, true);
                            while (curr_x >= r2.x + r2.width - 1) : (curr_x -= 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.HOR_ROAD, true);
                            }
                        }
                    } else {
                        std.debug.print("From room {d} to {d} going horizontal first", .{ k, k + 1 });
                        if (r2_center.x > r1_center.x) {
                            curr_x = r1.x + r1.width - 1;
                            while (curr_x <= r2_center.x) : (curr_x += 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.HOR_ROAD, true);
                            }
                            curr_x -= 1;
                        } else {
                            curr_x = r1.x;
                            while (curr_x >= r2_center.x) : (curr_x -= 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.HOR_ROAD, true);
                            }
                            curr_x += 1;
                        }
                        if (r2_center.y > r1_center.y) {
                            curr_y += 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_y += 1;
                            self.assign_tile(curr_x, curr_y, ForestTiles.VERT_ROAD, true);
                            while (curr_y <= r2.y) : (curr_y += 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.VERT_ROAD, true);
                            }
                        } else {
                            curr_y -= 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_y -= 1;
                            self.assign_tile(curr_x, curr_y, ForestTiles.VERT_ROAD, true);
                            while (curr_y >= r2.y + r2.height - 1) : (curr_y -= 1) {
                                self.assign_tile(curr_x, curr_y, ForestTiles.VERT_ROAD, true);
                            }
                        }
                    }
                }
            }
            const x_start = rand.intRangeAtMost(usize, 0, self.width - 1);
            const y_start = rand.intRangeAtMost(usize, 0, self.height - 1);
            try self.start_chunks.append(.{
                .chunk_info = .{
                    .tile = ForestTiles.FLOOR,
                    .x = x_start,
                    .y = y_start,
                },
            });
            //TODO build connecting roads
            //TODO add dungeon entrances
            //TODO add ability to move to new segments by reaching edges
        }
        //TODO add more parameters
        //TODO add generation
        fn _generate_dungeon(self: *Self, width: usize, height: usize, num_rooms: usize) Error!void {
            self.tex = Texture.init(self.allocator);
            self.tex.is_ascii = true;
            self.width = width;
            self.height = height;
            try self.tex.rect(@intCast(width), @intCast(height), 0, 0, 0, 255);
            for (0..self.tex.pixel_buffer.len) |i| {
                self.tex.pixel_buffer[i] = DungeonTiles.EMPTY.color;
                self.tex.background_pixel_buffer[i] = DungeonTiles.EMPTY.bck_color;
                self.tex.ascii_buffer[i] = DungeonTiles.EMPTY.symbol;
            }
            var cur_object: usize = 0;
            const MAX_ATTEMPTS = 20;
            var attempt: usize = 0;
            //TODO generate forest, probably break down world into patches that are connected with roads, and fill surrounding area with grass/trees
            //TODO will need to figure out how we want to break down the map, might just be a full grid and overwrite areas with connecting roads
            outer: while (cur_object < num_rooms) {
                if (attempt >= MAX_ATTEMPTS) break;
                var new_room = MapChunk.init(self.allocator);
                try new_room.build_room(self.width, self.height, 8);
                if (self.chunks.items.len == 0) {
                    try self.chunks.append(new_room);
                    cur_object += 1;
                } else {
                    for (0..self.chunks.items.len) |i| {
                        if (self.chunks.items[i].has_conflict(&new_room)) {
                            attempt += 1;
                            new_room.deinit();
                            continue :outer;
                        }
                    }
                    try self.chunks.append(new_room);
                    cur_object += 1;
                    attempt = 0;
                }
            }
            for (0..self.chunks.items.len) |k| {
                const room = self.chunks.items[k];
                var indx: usize = 0;
                for (room.y..room.y + room.height) |i| {
                    for (room.x..room.x + room.width) |j| {
                        self.assign_tile(j, i, room.tiles[indx], true);
                        indx += 1;
                    }
                }
            }
            for (0..self.chunks.items.len) |k| {
                if (k < self.chunks.items.len - 1) {
                    //find center of the two rooms
                    const r1 = self.chunks.items[k];
                    const r2 = self.chunks.items[k + 1];
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
                        std.debug.print("From room {d} to {d} going vertical first", .{ k, k + 1 });
                        if (r2_center.y > r1_center.y) {
                            curr_y = r1.y + r1.height - 1;
                            while (curr_y <= r2_center.y) : (curr_y += 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, DungeonTiles.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, DungeonTiles.VERT_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, DungeonTiles.VERT_WALL, false);
                            curr_y -= 1;
                        } else {
                            curr_y = r1.y;
                            while (curr_y >= r2_center.y) : (curr_y -= 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, DungeonTiles.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, DungeonTiles.VERT_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, DungeonTiles.VERT_WALL, false);
                            curr_y += 1;
                        }
                        if (r2_center.x > r1_center.x) {
                            curr_x += 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_x += 1;
                            self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                            while (curr_x <= r2.x) : (curr_x += 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                                self.assign_tile(curr_x, curr_y - 1, DungeonTiles.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, DungeonTiles.HOR_WALL, false);
                            }
                        } else {
                            curr_x -= 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_x -= 1;
                            self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                            while (curr_x >= r2.x + r2.width - 1) : (curr_x -= 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                                self.assign_tile(curr_x, curr_y - 1, DungeonTiles.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, DungeonTiles.HOR_WALL, false);
                            }
                        }
                    } else {
                        std.debug.print("From room {d} to {d} going horizontal first", .{ k, k + 1 });
                        if (r2_center.x > r1_center.x) {
                            curr_x = r1.x + r1.width - 1;
                            while (curr_x <= r2_center.x) : (curr_x += 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x, curr_y - 1, DungeonTiles.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, DungeonTiles.HOR_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_WALL, false);
                            curr_x -= 1;
                        } else {
                            curr_x = r1.x;
                            while (curr_x >= r2_center.x) : (curr_x -= 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x, curr_y - 1, DungeonTiles.HOR_WALL, false);
                                self.assign_tile(curr_x, curr_y + 1, DungeonTiles.HOR_WALL, false);
                            }
                            self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_WALL, false);
                            curr_x += 1;
                        }
                        if (r2_center.y > r1_center.y) {
                            curr_y += 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_y += 1;
                            self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                            while (curr_y <= r2.y) : (curr_y += 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, DungeonTiles.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, DungeonTiles.VERT_WALL, false);
                            }
                        } else {
                            curr_y -= 1;
                            while (r1.contains_point(.{ .x = curr_x, .y = curr_y })) curr_y -= 1;
                            self.assign_tile(curr_x, curr_y, DungeonTiles.HOR_FLOOR, false);
                            while (curr_y >= r2.y + r2.height - 1) : (curr_y -= 1) {
                                self.assign_tile(curr_x, curr_y, DungeonTiles.VERT_FLOOR, false);
                                //if (r2.contains_point(.{ .x = curr_x, .y = curr_y })) break;
                                self.assign_tile(curr_x - 1, curr_y, DungeonTiles.VERT_WALL, false);
                                self.assign_tile(curr_x + 1, curr_y, DungeonTiles.VERT_WALL, false);
                            }
                        }
                    }
                }
            }
            // place entrance and exit to map
            const start_room = rand.intRangeAtMost(usize, 0, num_rooms - 1);
            const start_room_x = rand.intRangeAtMost(usize, 1, self.chunks.items[start_room].width - 2);
            const start_room_y = rand.intRangeAtMost(usize, 1, self.chunks.items[start_room].height - 2);

            var exit_room = rand.intRangeAtMost(usize, 0, num_rooms - 1);
            while (exit_room == start_room) exit_room = rand.intRangeAtMost(usize, 0, num_rooms - 1);
            const exit_room_x = rand.intRangeAtMost(usize, 1, self.chunks.items[exit_room].width - 2);
            const exit_room_y = rand.intRangeAtMost(usize, 1, self.chunks.items[exit_room].height - 2);

            self.assign_tile(self.chunks.items[start_room].x + start_room_x, self.chunks.items[start_room].y + start_room_y, DungeonTiles.START, true);
            self.assign_tile(self.chunks.items[exit_room].x + exit_room_x, self.chunks.items[exit_room].y + exit_room_y, DungeonTiles.EXIT, true);
            try self.start_chunks.append(.{
                .chunk_info = .{
                    .tile = DungeonTiles.START,
                    .x = self.chunks.items[start_room].x + start_room_x,
                    .y = self.chunks.items[start_room].y + start_room_y,
                },
            });

            try self.exit_chunks.append(.{
                .chunk_info = .{
                    .tile = DungeonTiles.EXIT,
                    .x = self.chunks.items[exit_room].x + exit_room_x,
                    .y = self.chunks.items[exit_room].y + exit_room_y,
                },
            });
        }
        //TODO change to kwargs??
        pub fn generate(self: *Self, width: usize, height: usize, name: []const u8, num_rooms: usize) Error!void {
            self.name = try self.allocator.dupe(u8, name);
            switch (self.map_type) {
                .DUNGEON => try self._generate_dungeon(width, height, num_rooms),
                .FOREST => try self._generate_forest(width, height),
            }
        }

        pub fn draw(self: *Self, x: i32, y: i32, name_offset: usize, renderer: *AsciiGraphics(color_type), dest: ?Texture) Error!void {
            try renderer.draw_texture(self.tex, .{ .x = 0, .y = 0, .width = self.tex.width, .height = self.tex.height }, .{ .x = x, .y = y, .width = self.tex.width, .height = self.tex.height }, dest);
            for (0..self.name.len) |i| {
                const x_i32: i32 = @intCast(@as(i64, @bitCast(name_offset + i)));
                const y_i32: i32 = 0;
                renderer.draw_symbol(x_i32, y_i32, self.name[i], TEXT_COLOR, dest);
            }
        }
    };
}
