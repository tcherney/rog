const std = @import("std");
const engine = @import("engine");
const common = @import("common");
const map = @import("map.zig");

//TODO main world struct will house multiple maps
//TODO when player reaches exit go to next map
const ColorMode = engine.ascii_graphics.ColorMode;
const Allocator = std.mem.Allocator;
pub fn World(comptime color_type: ColorMode) type {
    return struct {
        allocator: Allocator,
        dungeons: []Dungeon = undefined,
        current_map: usize = undefined,
        pub const Map = map.Map(color_type);
        pub const Error = error{} | Allocator.Error | Map.Error;
        pub const Self = @This();
        pub const Dungeon = struct {
            allocator: Allocator,
            maps: []Map = undefined,
            pub fn init(allocator: Allocator) Dungeon {
                return .{
                    .allocator = allocator,
                };
            }

            pub fn deinit(self: *Dungeon) void {
                for (0..self.maps.len) |i| {
                    self.maps[i].deinit();
                }
            }
            pub fn generate(self: *Dungeon, width: usize, height: usize, n_rooms: usize, n_maps: usize) Error!void {
                self.maps = try self.allocator.alloc(Map, n_maps);
                for (0..self.maps.len) |i| {
                    try self.maps[i].generate(width, height, n_rooms);
                }
                //connect maps together
                for (1..self.maps.len) |i| {
                    self.maps[i].start_room.connect_rooms(self.maps[i - 1].exit_room, i, i - 1);
                }
            }
        };

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocaor = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            for (0..self.dungeons.len) |i| {
                self.dungeons[i].deinit();
            }
        }
        //TODO figure out params for world generation, perhaps a random seed
        pub fn generate(self: *Self) Error!void {
            const dungeons_to_gen = 3;
            const maps_per_dung = 2;
            const rooms_per_dungeon = 5;
            self.dungeons = try self.allocator.alloc(Dungeon, dungeons_to_gen);
            for (0..self.dungeons.len) |i| {
                try self.dungeons[i].generate(maps_per_dung);
            }
            //connect the dungeons
        }
    };
}
