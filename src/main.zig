const std = @import("std");
const builtin = @import("builtin");
const game = @import("game.zig");
pub const std_options: std.Options = .{
    .log_level = .err,
    .logFn = myLogFn,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .game, .level = .err },
        .{ .scope = .world, .level = .err },
        .{ .scope = .map, .level = .err },
    },
};

pub fn myLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ comptime level.asText() ++ "] (" ++ @tagName(scope) ++ "): ";
    // Print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format, args) catch return;
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator: std.mem.Allocator = undefined;
    if (builtin.os.tag == .emscripten) {
        allocator = std.heap.c_allocator;
    } else {
        allocator = gpa.allocator();
    }
    var app = try game.Game.init(allocator);
    try app.run();
    try app.deinit();
    if (builtin.os.tag != .emscripten and gpa.deinit() == .leak) {
        std.log.warn("Leaked!\n", .{});
    }
}
