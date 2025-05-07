const std = @import("std");
const engine = @import("engine");
const common = @import("common");
const map = @import("map.zig");
const player = @import("player.zig");

const ColorMode = engine.ascii_graphics.ColorMode;
const Allocator = std.mem.Allocator;
const AsciiGraphics = engine.AsciiGraphics;
const MapExit = map.MapExit;
const Texture = engine.Texture;
const Pixel = common.Pixel;
pub var scratch_buffer: [32]u8 = undefined;
//TODO move out to a constants/config file
const TEXT_COLOR = Pixel.init(255, 255, 255, null);

pub fn World(comptime color_type: ColorMode) type {
    return struct {
        allocator: Allocator,
        dungeons: []Dungeon = undefined,
        current_dungeon: usize = 0,
        pub const Map = map.Map(color_type);
        pub const Error = error{} || Allocator.Error || Map.Error || std.fmt.BufPrintError;
        pub const Self = @This();
        const Player = player.Player(color_type);
        pub const Dungeon = struct {
            allocator: Allocator,
            maps: []Map = undefined,
            entrance: MapExit = undefined,
            exit: MapExit = undefined,
            name: []u8 = undefined,
            current_map: usize = 0,
            pub fn init(allocator: Allocator) Dungeon {
                return .{
                    .allocator = allocator,
                };
            }

            pub fn deinit(self: *Dungeon) void {
                for (0..self.maps.len) |i| {
                    self.maps[i].deinit();
                }
                self.allocator.free(self.name);
                self.allocator.free(self.maps);
            }
            pub fn generate(self: *Dungeon, width: usize, height: usize, n_rooms: usize, n_maps: usize, name: []const u8) Error!void {
                self.maps = try self.allocator.alloc(Map, n_maps);
                self.name = try self.allocator.dupe(u8, name);
                for (0..self.maps.len) |i| {
                    self.maps[i] = Map.init(self.allocator, .DUNGEON);
                    try self.maps[i].generate(width, height, n_rooms, try std.fmt.bufPrint(&scratch_buffer, "Floor {d}", .{i}));
                }
                //connect maps together
                for (1..self.maps.len) |i| {
                    self.maps[i].start_room.connect_rooms(&self.maps[i - 1].exit_room, i, i - 1);
                }
                self.entrance = self.maps[0].start_room;
                self.exit = self.maps[n_maps - 1].exit_room;
            }
            pub fn draw(self: *Dungeon, x: i32, y: i32, renderer: *AsciiGraphics(color_type), dest: ?Texture) Error!void {
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
            for (0..self.dungeons.len) |i| {
                self.dungeons[i].deinit();
            }
            self.allocator.free(self.dungeons);
        }
        pub fn get_current_map(self: *Self) *Map {
            return &self.dungeons[self.current_dungeon].maps[self.dungeons[self.current_dungeon].current_map];
        }

        //TODO figure out params for world generation, perhaps a random seed
        //TODO could have the params wrapped into an object that is passed in
        pub fn generate(self: *Self, width: usize, height: usize) Error!void {
            const dungeons_to_gen = 3;
            const maps_per_dung = 2;
            const rooms_per_dungeon = 5;
            self.dungeons = try self.allocator.alloc(Dungeon, dungeons_to_gen);
            for (0..self.dungeons.len) |i| {
                self.dungeons[i] = Dungeon.init(self.allocator);
                try self.dungeons[i].generate(width, height, rooms_per_dungeon, maps_per_dung, try std.fmt.bufPrint(&scratch_buffer, "Dungeon {d}", .{i}));
            }
            //connect the dungeons
            //TODO utilize entrance and exit to connect the dungeons to other maps, in this case for now just connect the dungeons together
            for (1..self.dungeons.len) |i| {
                //TODO will have to think about this better, we currently would need an index to the proper dungeon as well, for now we will just assume its the next one in the list
                self.dungeons[i].entrance.connect_rooms(&self.dungeons[i - 1].exit, i, i - 1);
            }
        }

        pub fn draw(self: *Self, x: i32, y: i32, renderer: *AsciiGraphics(color_type), dest: ?Texture) Error!void {
            try self.dungeons[self.current_dungeon].draw(x, y, renderer, dest);
        }

        pub fn validate_player_position(self: *Self, p: *Player) void {
            const current_map = self.get_current_map();
            if (current_map.at_start(p.x, p.y)) {
                //move between maps in dungeon
                if (self.dungeons[self.current_dungeon].current_map > 0) {
                    std.debug.print("Moving back between maps\n", .{});
                    self.dungeons[self.current_dungeon].current_map -= 1;
                    const new_pos = self.dungeons[self.current_dungeon].maps[self.dungeons[self.current_dungeon].current_map].exit_map_coord();
                    p.x = @intCast(@as(i64, @bitCast(new_pos.x)));
                    p.y = @intCast(@as(i64, @bitCast(new_pos.y)));
                }
                // move to another dungeon
                else {
                    if (self.current_dungeon > 0) {
                        std.debug.print("Moving back between dungeons\n", .{});
                        self.current_dungeon -= 1;
                        self.dungeons[self.current_dungeon].current_map = self.dungeons[self.current_dungeon].maps.len - 1;
                        const new_pos = self.dungeons[self.current_dungeon].maps[self.dungeons[self.current_dungeon].current_map].exit_map_coord();
                        p.x = @intCast(@as(i64, @bitCast(new_pos.x)));
                        p.y = @intCast(@as(i64, @bitCast(new_pos.y)));
                    }
                }
            } else if (current_map.at_exit(p.x, p.y)) {
                //move between maps in dungeon
                if (self.dungeons[self.current_dungeon].current_map < self.dungeons[self.current_dungeon].maps.len - 1) {
                    std.debug.print("Moving up between maps\n", .{});
                    self.dungeons[self.current_dungeon].current_map += 1;
                    const new_pos = self.dungeons[self.current_dungeon].maps[self.dungeons[self.current_dungeon].current_map].start_map_coord();
                    p.x = @intCast(@as(i64, @bitCast(new_pos.x)));
                    p.y = @intCast(@as(i64, @bitCast(new_pos.y)));
                }
                // move to another dungeon
                else {
                    if (self.current_dungeon < self.dungeons.len - 1) {
                        std.debug.print("Moving up between dungeons\n", .{});
                        self.current_dungeon += 1;
                        self.dungeons[self.current_dungeon].current_map = 0;
                        const new_pos = self.dungeons[self.current_dungeon].maps[self.dungeons[self.current_dungeon].current_map].start_map_coord();
                        p.x = @intCast(@as(i64, @bitCast(new_pos.x)));
                        p.y = @intCast(@as(i64, @bitCast(new_pos.y)));
                    }
                }
            }
        }
    };
}
