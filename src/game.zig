const std = @import("std");
const engine = @import("engine");
const common = @import("common");
const map = @import("map.zig");
const player = @import("player.zig");
const world = @import("world.zig");

pub const COLOR_TYPE = .color_true;
pub const Engine = engine.Engine;
pub const DungeonMap = map.Map(COLOR_TYPE);
const GAME_LOG = std.log.scoped(.game);
pub const Player = player.Player;
pub const World = world.World(COLOR_TYPE);

pub const Game = struct {
    running: bool = true,
    e: Engine(.ascii, COLOR_TYPE) = undefined,
    allocator: std.mem.Allocator = undefined,
    frame_limit: u64 = 16_666_667,
    lock: std.Thread.Mutex = undefined,
    world: World,
    window: engine.Texture,
    player: Player(COLOR_TYPE) = undefined,
    const Self = @This();
    pub const Error = error{} || engine.Error || std.posix.GetRandomError || std.mem.Allocator.Error;
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return Self{
            .allocator = allocator,
            .world = World.init(allocator),
            .window = engine.Texture.init(allocator),
        };
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
        self.world.deinit();
        self.window.deinit();
    }

    pub fn on_mouse_change(self: *Self, mouse_event: engine.MouseEvent) void {
        GAME_LOG.info("{any}\n", .{mouse_event});
        _ = self;
    }
    pub fn on_window_change(self: *Self, win_size: engine.WindowSize) void {
        self.lock.lock();
        GAME_LOG.info("changed height {d}\n", .{win_size.height});
        self.lock.unlock();
    }

    pub fn on_key_down(self: *Self, key: engine.KEYS) void {
        GAME_LOG.info("{}\n", .{key});
        if (key == engine.KEYS.KEY_q) {
            self.running = false;
        } else if (key == engine.KEYS.KEY_w) {
            if (self.player.move(.UP, self.world.get_current_map())) {
                self.world.validate_player_position(&self.player);
            }
        } else if (key == engine.KEYS.KEY_a) {
            if (self.player.move(.LEFT, self.world.get_current_map())) {
                self.world.validate_player_position(&self.player);
            }
        } else if (key == engine.KEYS.KEY_s) {
            if (self.player.move(.DOWN, self.world.get_current_map())) {
                self.world.validate_player_position(&self.player);
            }
        } else if (key == engine.KEYS.KEY_d) {
            if (self.player.move(.RIGHT, self.world.get_current_map())) {
                self.world.validate_player_position(&self.player);
            }
        }
    }

    pub fn on_render(self: *Self, dt: u64) !void {
        self.e.renderer.set_bg(0, 0, 0, self.window);
        _ = dt;
        try self.world.draw(0, 0, &self.e.renderer, self.window);
        self.player.draw(&self.e.renderer, self.window);
        //GAME_LOG.info("color buffer {any}\n ascii buffer {any}", .{ self.window.pixel_buffer, self.window.ascii_buffer });
        try self.e.renderer.flip(self.window, null);
    }
    pub fn run(self: *Self) !void {
        self.lock = std.Thread.Mutex{};
        self.e = try Engine(.ascii, COLOR_TYPE).init(self.allocator);
        GAME_LOG.info("starting height {d}\n", .{self.e.renderer.terminal.size.height});
        self.window.is_ascii = true;
        try self.window.rect(@intCast(self.e.renderer.terminal.size.width), @intCast(self.e.renderer.terminal.size.height), 0, 0, 0, 255);
        try self.world.generate(@intCast(self.e.renderer.terminal.size.width), @intCast(self.e.renderer.terminal.size.height / 2));
        self.player = Player(COLOR_TYPE).init();
        self.player.x = @intCast(@as(i64, @bitCast(self.world.get_current_map().start_chunks.items[0].chunk_info.x)));
        self.player.y = @intCast(@as(i64, @bitCast(self.world.get_current_map().start_chunks.items[0].chunk_info.y)));
        self.e.on_key_down(Self, on_key_down, self);
        self.e.on_render(Self, on_render, self);
        self.e.on_mouse_change(Self, on_mouse_change, self);
        self.e.on_window_change(Self, on_window_change, self);
        self.e.set_fps(60);
        try common.gen_rand();
        try self.e.start();

        var timer: std.time.Timer = try std.time.Timer.start();
        var delta: u64 = 0;
        while (self.running) {
            delta = timer.read();
            timer.reset();
            self.lock.lock();
            self.player.update(delta);
            self.lock.unlock();
            delta = timer.read();
            timer.reset();
            const time_to_sleep: i64 = @as(i64, @bitCast(self.frame_limit)) - @as(i64, @bitCast(delta));
            if (time_to_sleep > 0) {
                std.time.sleep(@as(u64, @bitCast(time_to_sleep)));
            }
        }
    }
};
