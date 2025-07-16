const std = @import("std");
const builtin = @import("builtin");

fn createEmsdkStep(b: *std.Build, emsdk: *std.Build.Dependency) *std.Build.Step.Run {
    if (builtin.os.tag == .windows) {
        return b.addSystemCommand(&.{emsdk.path("emsdk.bat").getPath(b)});
    } else {
        return b.addSystemCommand(&.{emsdk.path("emsdk").getPath(b)});
    }
}

fn emSdkSetupStep(b: *std.Build, emsdk: *std.Build.Dependency) !?*std.Build.Step.Run {
    const dot_emsc_path = emsdk.path(".emscripten").getPath(b);
    std.debug.print("path {s}\n", .{dot_emsc_path});
    const dot_emsc_exists = !std.meta.isError(std.fs.accessAbsolute(dot_emsc_path, .{}));

    if (!dot_emsc_exists) {
        std.debug.print("path exists\n", .{});
        const emsdk_install = createEmsdkStep(b, emsdk);
        emsdk_install.addArgs(&.{ "install", "latest" });
        const emsdk_activate = createEmsdkStep(b, emsdk);
        emsdk_activate.addArgs(&.{ "activate", "latest" });
        emsdk_activate.step.dependOn(&emsdk_install.step);
        return emsdk_activate;
    } else {
        return null;
    }
}

fn emscriptenRunStep(b: *std.Build, emsdk: *std.Build.Dependency, examplePath: []const u8) !*std.Build.Step.Run {
    const dot_emsc_path = emsdk.path("upstream/emscripten").getPath(b);
    // If compiling on windows , use emrun.bat.
    const emrunExe = switch (builtin.os.tag) {
        .windows => "emrun.bat",
        else => "emrun",
    };
    var emrun_run_arg = try b.allocator.alloc(u8, dot_emsc_path.len + emrunExe.len + 1);
    defer b.allocator.free(emrun_run_arg);
    emrun_run_arg = try std.fmt.bufPrint(emrun_run_arg, "{s}" ++ std.fs.path.sep_str ++ "{s}", .{ dot_emsc_path, emrunExe });
    std.debug.print("dot_emsc_path {s}\n", .{dot_emsc_path});
    std.debug.print("emrun path {s}\n", .{emrun_run_arg});
    const run_cmd = b.addSystemCommand(&.{ emrun_run_arg, examplePath });
    return run_cmd;
}

const emccOutputDir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;
const emccOutputXtermDir = "htmlout" ++ std.fs.path.sep_str;
const emccOutputFile = "index.html";

pub const Error = error{ MissingDependency, InvalidArgs };

pub fn Build(b: *std.Build, s: ?*std.Build.Step.Compile, m: ?*std.Build.Module, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, root_source_file: std.Build.LazyPath, app_name: ?[]const u8, shell_file: ?[]const u8, preload_file: ?[]const u8) !*std.Build.Step {
    const wasm_mod = if (m == null) b.createModule(.{
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    }) else m.?;
    const name = if (app_name == null) "wasm" else app_name.?;
    const wasmlib = b.addLibrary(.{ .name = name, .linkage = .static, .root_module = wasm_mod });
    if (s != null) {
        wasmlib.step.dependOn(&s.?.step);
        wasmlib.linkLibrary(s.?);
    }
    wasmlib.linkLibC();
    if (b.lazyDependency("emsdk", .{})) |dep| {
        if (try emSdkSetupStep(b, dep)) |emSdkStep| {
            wasmlib.step.dependOn(&emSdkStep.step);
        }
        wasmlib.addIncludePath(dep.path("upstream/emscripten/cache/sysroot/include"));
        b.installArtifact(wasmlib);

        const emccOutputDirExample = b.pathJoin(&.{ emccOutputDir, name, std.fs.path.sep_str });
        const mkdir_command = switch (builtin.os.tag) {
            .windows => b.addSystemCommand(&.{ "cmd.exe", "/c", "if", "not", "exist", emccOutputDirExample, "mkdir", emccOutputDirExample }),
            else => b.addSystemCommand(&.{ "mkdir", "-p", emccOutputDirExample }),
        };
        const emcc_exe = switch (builtin.os.tag) {
            .windows => "emcc.bat",
            else => "emcc",
        };
        const emcc_exe_path = b.pathJoin(&.{ dep.path("upstream/emscripten").getPath(b), emcc_exe });
        const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_exe_path});
        emcc_command.step.dependOn(&mkdir_command.step);
        const emccOutputXtermCSS = b.pathJoin(&.{ emccOutputXtermDir, name, std.fs.path.sep_str, "xterm", std.fs.path.sep_str, "xterm.css" });
        const emccOutputXtermJS = b.pathJoin(&.{ emccOutputXtermDir, name, std.fs.path.sep_str, "xterm", std.fs.path.sep_str, "xterm.js" });
        const xterm_css = b.addInstallFileWithDir(b.path("src/xterm/xterm.css"), .{ .prefix = {} }, emccOutputXtermCSS);
        const xterm_js = b.addInstallFileWithDir(b.path("src/xterm/xterm.js"), .{ .prefix = {} }, emccOutputXtermJS);
        emcc_command.step.dependOn(&xterm_css.step);
        emcc_command.step.dependOn(&xterm_js.step);
        const emccOutputDirExampleWithFile = b.pathJoin(&.{ emccOutputDir, name, std.fs.path.sep_str, emccOutputFile });
        emcc_command.addArgs(&[_][]const u8{
            "-o",
            emccOutputDirExampleWithFile,
            "-sFULL-ES3=1",
            "-sUSE_GLFW=3",
            "-sSTACK_OVERFLOW_CHECK=1",
            "-sEXPORTED_RUNTIME_METHODS=['requestFullscreen']",
            "-sASYNCIFY",
            //"-sNO_EXIT_RUNTIME",
            "-sUSE_OFFSET_CONVERTER",
            "-sINITIAL_MEMORY=167772160",
            "-sALLOW_MEMORY_GROWTH",
            "-O3",
            "--emrun",
            "-sSINGLE_FILE",
        });
        if (preload_file != null) {
            emcc_command.addArg("--preload-file");
            emcc_command.addArg(b.path(preload_file.?).getPath(b));
        }

        if (shell_file != null) {
            emcc_command.addArg("--shell-file");
            emcc_command.addArg(b.path(shell_file.?).getPath(b));
        }
        const link_items: []const *std.Build.Step.Compile = &.{
            wasmlib,
        };
        for (link_items) |item| {
            emcc_command.addFileArg(item.getEmittedBin());
            emcc_command.step.dependOn(&item.step);
        }
        const run_step = try emscriptenRunStep(b, dep, emccOutputDirExampleWithFile);
        run_step.step.dependOn(&emcc_command.step);
        run_step.addArg("--no_browser");
        const run_option = b.step(name, name);
        run_option.dependOn(&run_step.step);
        return run_option;
    }
    return Error.MissingDependency;
}

pub const EmsdkWrapper = struct {
    const c = @cImport({
        @cInclude("emscripten/emscripten.h");
        @cInclude("emscripten/html5.h");
    });
    pub const EmscriptenMouseEvent = c.EmscriptenMouseEvent;
    pub const EmscriptenWheelEvent = c.EmscriptenWheelEvent;
    pub const EmscriptenTouchEvent = c.EmscriptenTouchEvent;
    pub const EmscriptenKeyboardEvent = c.EmscriptenKeyboardEvent;
    pub extern fn emscripten_set_main_loop(*const fn () callconv(.C) void, c_int, c_int) void;
    pub extern fn emscripten_set_main_loop_arg(*const fn (*anyopaque) callconv(.C) void, *anyopaque, c_int, c_int) void;
    pub extern fn emscripten_sleep(c_uint) void;
    pub extern fn emscripten_request_animation_frame_loop(*const fn (f64, *anyopaque) callconv(.C) bool, *anyopaque) void;
    pub extern fn emscripten_run_script([]const u8) void;
    pub fn emscripten_set_click_callback(target: [*:0]const u8, ctx: *anyopaque, use_capture: bool, handler: ?*const fn (c_int, ?*const EmscriptenMouseEvent, ?*anyopaque) callconv(.C) bool) c_int {
        //_ = target;
        //const window: [*:0]const u8 = @ptrFromInt(2);
        return c.emscripten_set_click_callback(target, ctx, use_capture, handler);
    }
    pub fn emscripten_set_mousedown_callback(target: [*:0]const u8, ctx: *anyopaque, use_capture: bool, handler: ?*const fn (c_int, ?*const EmscriptenMouseEvent, ?*anyopaque) callconv(.C) bool) c_int {
        //_ = target;
        //const window: [*:0]const u8 = @ptrFromInt(2);
        return c.emscripten_set_mousedown_callback(target, ctx, use_capture, handler);
    }
    pub fn emscripten_set_mousemove_callback(target: [*:0]const u8, ctx: *anyopaque, use_capture: bool, handler: ?*const fn (c_int, ?*const EmscriptenMouseEvent, ?*anyopaque) callconv(.C) bool) c_int {
        //_ = target;
        //const window: [*:0]const u8 = @ptrFromInt(2);
        return c.emscripten_set_mousemove_callback(target, ctx, use_capture, handler);
    }
    pub fn emscripten_set_touchstart_callback(target: [*:0]const u8, ctx: *anyopaque, use_capture: bool, handler: ?*const fn (c_int, ?*const EmscriptenTouchEvent, ?*anyopaque) callconv(.C) bool) c_int {
        //_ = target;
        //const window: [*:0]const u8 = @ptrFromInt(2);
        return c.emscripten_set_touchstart_callback(target, ctx, use_capture, handler);
    }
    pub fn emscripten_set_touchmove_callback(target: [*:0]const u8, ctx: *anyopaque, use_capture: bool, handler: ?*const fn (c_int, ?*const EmscriptenTouchEvent, ?*anyopaque) callconv(.C) bool) c_int {
        //_ = target;
        //const window: [*:0]const u8 = @ptrFromInt(2);
        return c.emscripten_set_touchmove_callback(target, ctx, use_capture, handler);
    }

    pub fn emscripten_set_wheel_callback(target: [*:0]const u8, ctx: *anyopaque, use_capture: bool, handler: ?*const fn (c_int, ?*const EmscriptenWheelEvent, ?*anyopaque) callconv(.C) bool) c_int {
        //_ = target;
        //const window: [*:0]const u8 = @ptrFromInt(2);
        return c.emscripten_set_wheel_callback(target, ctx, use_capture, handler);
    }

    pub fn emscripten_set_keydown_callback(target: [*:0]const u8, ctx: *anyopaque, use_capture: bool, handler: ?*const fn (c_int, ?*const EmscriptenKeyboardEvent, ?*anyopaque) callconv(.C) bool) c_int {
        //_ = target;
        //const window: [*:0]const u8 = @ptrFromInt(2);
        return c.emscripten_set_keydown_callback(target, ctx, use_capture, handler);
    }
};
