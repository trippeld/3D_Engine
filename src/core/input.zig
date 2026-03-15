pub const State = struct {
    move_forward: bool = false,
    move_backward: bool = false,
    move_left: bool = false,
    move_right: bool = false,
    move_up: bool = false,
    move_down: bool = false,

    mouse_delta_x: f32 = 0.0,
    mouse_delta_y: f32 = 0.0,

    pub fn reset_frame_deltas(self: *State) void {
        self.mouse_delta_x = 0.0;
        self.mouse_delta_y = 0.0;
    }
};
