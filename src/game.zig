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
    const Self = @This();
    pub const Error = error{} || engine.Error || std.posix.GetRandomError || std.mem.Allocator.Error;
    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return Self{
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *Self) Error!void {
        try self.e.deinit();
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
        }
    }

    pub fn on_render(self: *Self, dt: u64) !void {
        //self.e.renderer.set_bg(0, 0, 0, self.current_world.tex);
        _ = self;
        _ = dt;
        //try self.e.renderer.flip(self.current_world.tex, self.current_world.viewport);
    }
    pub fn run(self: *Self) !void {
        self.lock = std.Thread.Mutex{};
        self.e = try Engine(.ascii, .color_true).init(self.allocator);
        GAME_LOG.info("starting height {d}\n", .{self.e.renderer.terminal.size.height});
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
