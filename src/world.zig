const std = @import("std");
const engine = @import("engine");
const common = @import("common");
const map = @import("map.zig");
const player = @import("player.zig");

const Allocator = std.mem.Allocator;
const AsciiRenderer = engine.graphics.AsciiRenderer;
const MapExit = map.MapExit;
const Texture = engine.Texture;
const Pixel = common.Pixel;
const rand = std.crypto.random;
pub var scratch_buffer: [32]u8 = undefined;
const WORLD_LOG = std.log.scoped(.world);
//TODO move out to a constants/config file
const TEXT_COLOR = common.Colors.WHITE;

pub const World = struct {
    allocator: Allocator,
    map_cols: []MapCollection = undefined,
    current_map_col: usize = 0,
    pub const Map = map.Map;
    pub const Error = error{} || Allocator.Error || Map.Error || std.fmt.BufPrintError;
    pub const Self = @This();
    const Player = player.Player;
    pub const MapCollection = struct {
        allocator: Allocator,
        maps: []Map = undefined,
        name: []u8 = undefined,
        current_map: usize = 0,
        pub fn init(allocator: Allocator) MapCollection {
            return .{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *MapCollection) void {
            for (0..self.maps.len) |i| {
                self.maps[i].deinit();
            }
            self.allocator.free(self.name);
            self.allocator.free(self.maps);
        }
        pub fn generate_forest(self: *MapCollection, width: usize, height: usize, n_maps: usize, name: []const u8) Error!void {
            self.maps = try self.allocator.alloc(Map, n_maps);
            self.name = try self.allocator.dupe(u8, name);
            for (0..self.maps.len) |i| {
                self.maps[i] = Map.init(self.allocator, .FOREST);
                try self.maps[i].generate(width, height, try std.fmt.bufPrint(&scratch_buffer, "Floor {d}", .{i}), 0);
            }
            // //TODO connect maps together
            // for (1..self.maps.len) |i| {
            //     self.maps[i].start_chunk.connect_chunks(&self.maps[i - 1].exit_chunk, i, i - 1);
            // }
            // self.entrance = self.maps[0].start_chunk;
            // self.exit = self.maps[n_maps - 1].exit_chunk;
        }
        pub fn generate_dungeon(self: *MapCollection, width: usize, height: usize, n_rooms: usize, n_maps: usize, indx: usize, name: []const u8) Error!void {
            self.maps = try self.allocator.alloc(Map, n_maps);
            self.name = try self.allocator.dupe(u8, name);
            for (0..self.maps.len) |i| {
                self.maps[i] = Map.init(self.allocator, .DUNGEON);
                try self.maps[i].generate(width, height, try std.fmt.bufPrint(&scratch_buffer, "Floor {d}", .{i}), n_rooms);
            }
            //connect maps together
            for (1..self.maps.len) |i| {
                self.maps[i].start_chunks.items[0].connect_chunks(&self.maps[i - 1].exit_chunks.items[0], i, i - 1, indx, indx);
            }
        }
        pub fn draw(self: *MapCollection, x: i32, y: i32, renderer: *AsciiRenderer, dest: ?Texture) Error!void {
            // calc offsets
            const window_center = renderer.terminal.size.width / 2;
            const name_center = self.name.len / 2;
            const name_offset = window_center - name_center;
            const floor_offset = name_offset + self.name.len + 1;
            // draw map first
            try self.maps[self.current_map].draw(x, y, floor_offset, renderer, dest);
            // draw last to keep on top
            for (0..self.name.len) |i| {
                const x_i32: i32 = @intCast(@as(i64, @bitCast(name_offset + i)));
                const y_i32: i32 = 0;
                renderer.draw_symbol(x_i32, y_i32, self.name[i], TEXT_COLOR, dest);
            }
        }
    };

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (0..self.map_cols.len) |i| {
            self.map_cols[i].deinit();
        }
        self.allocator.free(self.map_cols);
    }
    pub fn get_current_map(self: *Self) *Map {
        return &self.map_cols[self.current_map_col].maps[self.map_cols[self.current_map_col].current_map];
    }

    //TODO figure out params for world generation, perhaps a random seed
    //TODO could have the params wrapped into an object that is passed in
    pub fn generate(self: *Self, width: usize, height: usize) Error!void {
        const dungeons_to_gen = 3;
        const maps_per_dung = 2;
        const rooms_per_dungeon = 5;
        self.map_cols = try self.allocator.alloc(MapCollection, dungeons_to_gen + 1);
        // overworld is index 0
        self.map_cols[0] = MapCollection.init(self.allocator);
        try self.map_cols[0].generate_forest(width, height, 1, "World");
        for (1..self.map_cols.len) |i| {
            self.map_cols[i] = MapCollection.init(self.allocator);
            try self.map_cols[i].generate_dungeon(width, height, rooms_per_dungeon, maps_per_dung, i, try std.fmt.bufPrint(&scratch_buffer, "Dungeon {d}", .{i}));
        }
        //connect the dungeons
        const num_overworld_chunks = self.map_cols[0].maps[self.map_cols[0].current_map].chunks.items.len;
        WORLD_LOG.info("num overworld chunks {d}\n", .{num_overworld_chunks});
        for (1..self.map_cols.len) |i| {
            var chunk_id = rand.intRangeAtMost(usize, 0, num_overworld_chunks - 1);
            WORLD_LOG.info("chunk id before {d}\n", .{chunk_id});
            while (self.map_cols[0].maps[self.map_cols[0].current_map].chunks.items[chunk_id].tiles[0].symbol == map.ForestTiles.EXIT.symbol) {
                chunk_id = rand.intRangeAtMost(usize, 0, num_overworld_chunks - 1);
            }
            WORLD_LOG.info("chunk id after {d}\n", .{chunk_id});
            const new_exit: MapExit = .{
                .chunk_info = .{
                    .tile = map.ForestTiles.EXIT,
                    .x = self.map_cols[0].maps[self.map_cols[0].current_map].chunks.items[chunk_id].x,
                    .y = self.map_cols[0].maps[self.map_cols[0].current_map].chunks.items[chunk_id].y,
                },
            };
            //TODO clean this up to be more readable
            try self.map_cols[0].maps[0].exit_chunks.append(new_exit);
            self.map_cols[0].maps[self.map_cols[0].current_map].assign_tile(self.map_cols[0].maps[0].exit_chunks.items[self.map_cols[0].maps[0].exit_chunks.items.len - 1].chunk_info.x, self.map_cols[0].maps[0].exit_chunks.items[self.map_cols[0].maps[0].exit_chunks.items.len - 1].chunk_info.y, map.ForestTiles.EXIT, true);
            self.map_cols[i].maps[0].start_chunks.items[0].connect_chunks(&self.map_cols[0].maps[0].exit_chunks.items[self.map_cols[0].maps[0].exit_chunks.items.len - 1], 0, 0, i, 0);
        }
    }

    pub fn draw(self: *Self, x: i32, y: i32, renderer: *AsciiRenderer, dest: ?Texture) Error!void {
        try self.map_cols[self.current_map_col].draw(x, y, renderer, dest);
    }

    pub fn validate_player_position(self: *Self, p: *Player) void {
        const current_map = self.get_current_map();
        //TODO instead, handle map edge transitions
        if (p.x < 0) p.x = 0;
        if (p.y < 0) p.y = 0;
        if (p.x >= @as(i32, @intCast(@as(i64, @bitCast(current_map.width))))) p.x = @as(i32, @intCast(@as(i64, @bitCast(current_map.width - 1))));
        if (p.y >= @as(i32, @intCast(@as(i64, @bitCast(current_map.height))))) p.y = @as(i32, @intCast(@as(i64, @bitCast(current_map.height - 1))));
        if (current_map.at_start(p.x, p.y)) {
            var exit: *MapExit = undefined;
            const x_usize: usize = @intCast(@as(u32, @bitCast(p.x)));
            const y_usize: usize = @intCast(@as(u32, @bitCast(p.y)));
            for (0..current_map.start_chunks.items.len) |i| {
                if (current_map.start_chunks.items[i].chunk_info.x == x_usize and current_map.start_chunks.items[i].chunk_info.y == y_usize) {
                    exit = &current_map.start_chunks.items[i];
                }
            }
            if (exit.connected) {
                self.current_map_col = exit.ext_map_col_indx;
                self.map_cols[self.current_map_col].current_map = exit.ext_map_indx;
                p.x = @intCast(@as(i64, @bitCast(exit.ext_chunk_info.x)));
                p.y = @intCast(@as(i64, @bitCast(exit.ext_chunk_info.y)));
            }
        } else if (current_map.at_exit(p.x, p.y)) {
            var start: *MapExit = undefined;
            const x_usize: usize = @intCast(@as(u32, @bitCast(p.x)));
            const y_usize: usize = @intCast(@as(u32, @bitCast(p.y)));
            for (0..current_map.exit_chunks.items.len) |i| {
                if (current_map.exit_chunks.items[i].chunk_info.x == x_usize and current_map.exit_chunks.items[i].chunk_info.y == y_usize) {
                    start = &current_map.exit_chunks.items[i];
                    WORLD_LOG.info("Found exit\n", .{});
                    break;
                }
            }
            if (start.connected) {
                self.current_map_col = start.ext_map_col_indx;
                self.map_cols[self.current_map_col].current_map = start.ext_map_indx;
                p.x = @intCast(@as(i64, @bitCast(start.ext_chunk_info.x)));
                p.y = @intCast(@as(i64, @bitCast(start.ext_chunk_info.y)));
            }
        }
    }
};
