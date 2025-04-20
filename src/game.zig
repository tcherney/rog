const std = @import("std");
const engine = @import("engine");
const common = @import("common");

pub const Engine = engine.Engine;
const GAME_LOG = std.log.scoped(.game);

pub const Game = struct {
    running: bool = true,
    e: Engine(.ascii, .color_true) = undefined,
    allocator: std.mem.Allocator = undefined,
    frame_limit: u64 = 16_666_667,
    lock: std.Thread.Mutex = undefined,
    world: engine.Texture,
    window: engine.Texture,
    player: struct { x: i32, y: i32, color: common.Pixel, symbol: u8 } = .{ .x = 0, .y = 0, .color = common.Pixel.init(0, 0, 255, null), .symbol = '@' },
    const Self = @This();
    pub const Error = error{} || engine.Error || std.posix.GetRandomError || std.mem.Allocator.Error;
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return Self{
            .allocator = allocator,
            .world = engine.Texture.init(allocator),
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
            self.player.y -= 1;
        } else if (key == engine.KEYS.KEY_a) {
            self.player.x -= 1;
        } else if (key == engine.KEYS.KEY_s) {
            self.player.y += 1;
        } else if (key == engine.KEYS.KEY_d) {
            self.player.x += 1;
        }
    }

    pub fn on_render(self: *Self, dt: u64) !void {
        self.e.renderer.set_bg(0, 0, 0, self.window);
        _ = dt;
        try self.e.renderer.draw_ascii_buffer(self.world.pixel_buffer, self.world.background_pixel_buffer, self.world.ascii_buffer, self.world.width, self.world.height, common.Rectangle{ .x = 0, .y = 0, .width = self.world.width, .height = self.world.height }, common.Rectangle{ .x = 0, .y = 0, .width = self.world.width, .height = self.world.height }, self.window);
        self.e.renderer.draw_symbol(self.player.x, self.player.y, self.player.symbol, self.player.color, self.window);
        GAME_LOG.info("color buffer {any}\n ascii buffer {any}", .{ self.window.pixel_buffer, self.window.ascii_buffer });
        try self.e.renderer.flip(self.window, null);
    }
    pub fn run(self: *Self) !void {
        self.lock = std.Thread.Mutex{};
        self.e = try Engine(.ascii, .color_true).init(self.allocator);
        GAME_LOG.info("starting height {d}\n", .{self.e.renderer.terminal.size.height});
        self.world.is_ascii = true;
        self.window.is_ascii = true;
        try self.window.rect(@intCast(self.e.renderer.terminal.size.width), @intCast(self.e.renderer.terminal.size.height), 0, 0, 0, 255);
        try self.world.rect(@intCast(self.e.renderer.terminal.size.width), @intCast(self.e.renderer.terminal.size.height), 255, 0, 0, 255);
        for (0..self.world.ascii_buffer.len) |i| {
            self.world.ascii_buffer[i] = '#';
        }
        for (0..self.world.background_pixel_buffer.len) |i| {
            self.world.background_pixel_buffer[i] = common.Pixel.init(0, 255, 0, null);
        }
        self.e.on_key_down(Self, on_key_down, self);
        self.e.on_render(Self, on_render, self);
        self.e.on_mouse_change(Self, on_mouse_change, self);
        self.e.on_window_change(Self, on_window_change, self);
        self.e.set_fps(60);
        try self.e.start();

        var timer: std.time.Timer = try std.time.Timer.start();
        var delta: u64 = 0;
        while (self.running) {
            delta = timer.read();
            timer.reset();
            self.lock.lock();

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
