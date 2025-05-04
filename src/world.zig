const std = @import("std");
const engine = @import("engine");
const common = @import("common");
const map = @import("map.zig");

//TODO main world struct will house multiple maps
//TODO when player reaches exit go to next map
const ColorMode = engine.ascii_graphics.ColorMode;
const Allocator = std.mem.Allocator;
const AsciiGraphics = engine.AsciiGraphics;
const MapExit = map.MapExit;
const Texture = engine.Texture;
pub var scratch_buffer: [32]u8 = undefined;
pub fn World(comptime color_type: ColorMode) type {
    return struct {
        allocator: Allocator,
        dungeons: []Dungeon = undefined,
        current_dungeon: usize = 0,
        pub const Map = map.Map(color_type);
        pub const Error = error{} || Allocator.Error || Map.Error || std.fmt.BufPrintError;
        pub const Self = @This();
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
            }
            pub fn generate(self: *Dungeon, width: usize, height: usize, n_rooms: usize, n_maps: usize, name: []const u8) Error!void {
                std.debug.print("Test {s}\n", .{name});
                self.maps = try self.allocator.alloc(Map, n_maps);
                self.name = try self.allocator.dupe(u8, name);
                std.debug.print("Alloc good \n", .{});
                for (0..self.maps.len) |i| {
                    self.maps[i] = Map.init(self.allocator, .DUNGEON);
                    try self.maps[i].generate(width, height, n_rooms);
                }
                //connect maps together
                for (1..self.maps.len) |i| {
                    self.maps[i].start_room.connect_rooms(&self.maps[i - 1].exit_room, i, i - 1);
                }
                //TODO set entrance and exit to be start of first room and exit of last room respecitively
                self.entrance = self.maps[0].start_room;
                self.exit = self.maps[n_maps - 1].exit_room;
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
            try renderer.draw_texture(self.get_current_map().tex, .{ .x = 0, .y = 0, .width = self.get_current_map().tex.width, .height = self.get_current_map().tex.height }, .{ .x = x, .y = y, .width = self.get_current_map().tex.width, .height = self.get_current_map().tex.height }, dest);
        }
    };
}
