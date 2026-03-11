const std = @import("std");
const input = @import("../core/input.zig");

pub const c = @import("c.zig").c;

pub const Window = c.SDL_Window;

pub const Key = enum {
    escape,
};

pub const MouseMotion = struct {
    dx: f32,
    dy: f32,
};

pub const Event = union(enum) {
    none,
    quit,
    key_down: Key,
    mouse_motion: MouseMotion,
};

pub const Timer = struct {
    last_counter: u64,
    perf_freq: f64,
    elapsed_seconds: f32 = 0.0,

    pub fn start() Timer {
        return .{
            .last_counter = c.SDL_GetPerformanceCounter(),
            .perf_freq = @floatFromInt(c.SDL_GetPerformanceFrequency()),
        };
    }

    pub fn tick(self: *Timer) f32 {
        const now = c.SDL_GetPerformanceCounter();
        const dt: f32 = @floatCast(
            (@as(f64, @floatFromInt(now - self.last_counter))) / self.perf_freq,
        );
        self.last_counter = now;
        self.elapsed_seconds += dt;
        return dt;
    }

    pub fn total_time(self: *const Timer) f32 {
        return self.elapsed_seconds;
    }
};

pub fn init() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("SDL_Init failed: {s}", .{c.SDL_GetError()});
        return error.SdlInitFailed;
    }
}

pub fn quit() void {
    c.SDL_Quit();
}

pub fn create_window(title: [:0]const u8, width: i32, height: i32) !*Window {
    const window = c.SDL_CreateWindow(
        title.ptr,
        width,
        height,
        c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.log.err("SDL_CreateWindow failed: {s}", .{c.SDL_GetError()});
        return error.WindowCreateFailed;
    };

    return window;
}

pub fn destroy_window(window: *Window) void {
    c.SDL_DestroyWindow(window);
}

pub fn set_relative_mouse_mode(window: *Window, enabled: bool) !void {
    if (!c.SDL_SetWindowRelativeMouseMode(window, enabled)) {
        std.log.err("SDL_SetWindowRelativeMouseMode failed: {s}", .{c.SDL_GetError()});
        return error.RelativeMouseModeFailed;
    }
}

pub fn poll_event() ?Event {
    var raw: c.SDL_Event = undefined;

    if (!c.SDL_PollEvent(&raw)) return null;

    switch (raw.type) {
        c.SDL_EVENT_QUIT => return .quit,
        c.SDL_EVENT_KEY_DOWN => {
            if (raw.key.key == c.SDLK_ESCAPE) {
                return .{ .key_down = .escape };
            }
        },
        c.SDL_EVENT_MOUSE_MOTION => {
            return .{
                .mouse_motion = .{
                    .dx = @as(f32, @floatCast(raw.motion.xrel)),
                    .dy = @as(f32, @floatCast(raw.motion.yrel)),
                },
            };
        },
        else => {},
    }

    return .none;
}

pub fn read_input_state() input.State {
    const keyboard = c.SDL_GetKeyboardState(null);

    return .{
        .move_forward = keyboard[c.SDL_SCANCODE_W],
        .move_backward = keyboard[c.SDL_SCANCODE_S],
        .move_left = keyboard[c.SDL_SCANCODE_A],
        .move_right = keyboard[c.SDL_SCANCODE_D],
        .move_up = keyboard[c.SDL_SCANCODE_SPACE],
        .move_down = keyboard[c.SDL_SCANCODE_LCTRL] or keyboard[c.SDL_SCANCODE_RCTRL],
    };
}

pub fn delay_ms(ms: u32) void {
    c.SDL_Delay(ms);
}
