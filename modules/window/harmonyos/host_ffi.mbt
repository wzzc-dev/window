///|
/// Native host bridge: C owns a HostCmd queue; MoonBit drains it each pump.
/// host_push remains available for pure host-sim tests without C.

///|
extern "C" fn mbw_harmonyos_host_queue_reset() -> Unit = "mbw_harmonyos_host_queue_reset"

///|
/// Polls one native host event. Returns kind (0 = empty).
#borrow(handle_out, token_out, width_out, height_out, pressed_out, codepoint_out, scale_out, x_out, y_out, delta_x_out, delta_y_out, key_code_out, key_modifiers_out, key_kind_out)
extern "C" fn mbw_harmonyos_host_poll_raw(
  handle_out : Ref[UInt64],
  token_out : Ref[UInt64],
  width_out : Ref[Int32],
  height_out : Ref[Int32],
  pressed_out : Ref[Int32],
  codepoint_out : Ref[Int32],
  scale_out : Ref[Double],
  x_out : Ref[Double],
  y_out : Ref[Double],
  delta_x_out : Ref[Double],
  delta_y_out : Ref[Double],
  key_code_out : Ref[Int32],
  key_modifiers_out : Ref[Int32],
  key_kind_out : Ref[Int32],
) -> Int32 = "mbw_harmonyos_host_poll_raw"

///|
fn host_drain_native_queue() -> Unit {
  while true {
    let handle = Ref(0UL)
    let token = Ref(0UL)
    let width = Ref(0)
    let height = Ref(0)
    let pressed = Ref(0)
    let codepoint = Ref(0)
    let scale = Ref(1.0)
    let x = Ref(0.0)
    let y = Ref(0.0)
    let delta_x = Ref(0.0)
    let delta_y = Ref(0.0)
    let key_code = Ref(0)
    let key_modifiers = Ref(0)
    let key_kind = Ref(0)
    let kind = mbw_harmonyos_host_poll_raw(
      handle, token, width, height, pressed, codepoint, scale, x, y, delta_x, delta_y,
      key_code, key_modifiers, key_kind,
    )
    if kind == 0 {
      break
    }
    match kind {
      1 => host_push(Start)
      2 => host_push(Resume)
      3 => host_push(Pause)
      4 => host_push(Stop)
      5 =>
        host_push(
          SurfaceInit(handle.val, token.val, width.val, height.val, scale.val),
        )
      6 => host_push(SurfaceTerm)
      7 => host_push(SurfaceResize(width.val, height.val, scale.val))
      8 => host_push(PointerMoved(x.val, y.val))
      9 => host_push(PointerButton(pressed.val != 0, x.val, y.val))
      10 =>
        if codepoint.val > 0 {
          host_push(KeyboardText(codepoint.val.unsafe_to_char().to_string()))
        }
      11 => host_push(MemoryWarning)
      12 => host_push(Destroy)
      13 => host_push_command(Scroll(x.val, y.val, delta_x.val, delta_y.val))
      14 =>
        if key_kind.val != 0 {
          host_push_command(
            KeyPress(key_code.val, key_modifiers.val, pressed.val != 0),
          )
        }
      _ => ()
    }
  }
}

///|
fn host_reset_native_queue() -> Unit {
  mbw_harmonyos_host_queue_reset()
}

///|
extern "C" fn mbw_harmonyos_vsync_init() -> Int32 = "mbw_harmonyos_vsync_init"

///|
extern "C" fn mbw_harmonyos_wait_for_vsync(timeout_ms : Int32) -> Int32 = "mbw_harmonyos_wait_for_vsync"

///|
/// Creates the vsync connection used for frame pacing. Returns whether vsync is
/// available; when it is not, the loop falls back to a timed sleep.
pub fn host_vsync_init() -> Bool {
  mbw_harmonyos_vsync_init() != 0
}

///|
/// Blocks until the next display vsync, or `timeout_ms` when no signal arrives.
/// Returns whether the wait ended on a vsync.
pub fn host_wait_for_vsync(timeout_ms : Int32) -> Bool {
  mbw_harmonyos_wait_for_vsync(timeout_ms) != 0
}

///|
extern "C" fn mbw_harmonyos_monotonic_ms() -> Double = "mbw_harmonyos_monotonic_ms"

///|
/// Monotonic milliseconds for frame timing. Only differences are meaningful.
pub fn host_monotonic_ms() -> Double {
  mbw_harmonyos_monotonic_ms()
}
