///|
/// Native host bridge: C owns a HostCmd queue; MoonBit drains it each pump.
/// host_push remains available for pure host-sim tests without C.

///|
extern "C" fn mbw_ios_host_queue_reset() -> Unit = "mbw_ios_host_queue_reset"

///|
/// Polls one native host event. Returns kind (0 = empty).
#borrow(handle_out, token_out, width_out, height_out, pressed_out, codepoint_out, scale_out, x_out, y_out, phase_out, ime_kind_out, ime_start_out, ime_end_out, dx_out, dy_out)
extern "C" fn mbw_ios_host_poll_raw(
  handle_out : Ref[UInt64],
  token_out : Ref[UInt64],
  width_out : Ref[Int],
  height_out : Ref[Int],
  pressed_out : Ref[Int],
  codepoint_out : Ref[Int],
  scale_out : Ref[Double],
  x_out : Ref[Double],
  y_out : Ref[Double],
  phase_out : Ref[Int],
  ime_kind_out : Ref[Int],
  ime_start_out : Ref[Int],
  ime_end_out : Ref[Int],
  dx_out : Ref[Double],
  dy_out : Ref[Double],
) -> Int = "mbw_ios_host_poll_raw"

///|
/// Returns the text carried by the most recently polled IME host event
/// (kind == 15), copying it into a fresh MoonBit `Bytes`. Safe to call from
/// any poll iteration; only meaningful after an IME event was returned.
extern "C" fn mbw_ios_host_take_pending_ime_text() -> Bytes = "mbw_ios_host_take_pending_ime_text"

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
    let phase = Ref(0)
    let ime_kind = Ref(0)
    let ime_start = Ref(0)
    let ime_end = Ref(0)
    let dx = Ref(0.0)
    let dy = Ref(0.0)
    let kind = mbw_ios_host_poll_raw(
      handle, token, width, height, pressed, codepoint, scale, x, y, phase, ime_kind,
      ime_start, ime_end, dx, dy,
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
      13 => host_push(PointerPhase(phase.val, x.val, y.val))
      14 => host_push(Scroll(x.val, y.val, dx.val, dy.val, phase.val))
      15 => {
        // The native host memcpy'd the IME text into a bytes buffer; decode
        // it as UTF-8 (not Bytes::to_string, which is the `b"..."` debug form
        // and would leak inspect syntax into the runtime text).
        let bytes = mbw_ios_host_take_pending_ime_text()
        let text = @utf8.decode_lossy(bytes[:], ignore_bom=false)
        host_push(ImeEvent(ime_kind.val, text, ime_start.val, ime_end.val))
      }
      _ => ()
    }
  }
}

///|
fn host_reset_native_queue() -> Unit {
  mbw_ios_host_queue_reset()
}
