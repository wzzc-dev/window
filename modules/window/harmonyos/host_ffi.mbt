///|
/// Native host bridge: C owns a HostCmd queue; MoonBit drains it each pump.
/// host_push remains available for pure host-sim tests without C.

///|
extern "C" fn mbw_harmonyos_host_queue_reset() -> Unit = "mbw_harmonyos_host_queue_reset"

///|
/// Polls one native host event. Returns kind (0 = empty).
#borrow(handle_out, token_out, width_out, height_out, pressed_out, codepoint_out, scale_out, x_out, y_out)
extern "C" fn mbw_harmonyos_host_poll_raw(
  handle_out : Ref[UInt64],
  token_out : Ref[UInt64],
  width_out : Ref[Int],
  height_out : Ref[Int],
  pressed_out : Ref[Int],
  codepoint_out : Ref[Int],
  scale_out : Ref[Double],
  x_out : Ref[Double],
  y_out : Ref[Double],
) -> Int = "mbw_harmonyos_host_poll_raw"

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
    let kind = mbw_harmonyos_host_poll_raw(
      handle, token, width, height, pressed, codepoint, scale, x, y,
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
      _ => ()
    }
  }
}

///|
fn host_reset_native_queue() -> Unit {
  mbw_harmonyos_host_queue_reset()
}
