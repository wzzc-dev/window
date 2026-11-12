///|
/// Display-refresh frame clock for hosts that drive their own pump loop.
///
/// The native side owns a `CVDisplayLink` bound to the display that owns the
/// window's content view. Its callback runs on a CoreVideo thread and only
/// signals a semaphore; no MoonBit callback ever runs off the main thread.
/// Hosts call [`host_wait_for_vsync`] on the main thread before producing a
/// frame so the frame starts on a refresh boundary instead of an arbitrary
/// timer phase.
///
/// The API mirrors the HarmonyOS host (`host_vsync_init` /
/// `host_wait_for_vsync`) so platform host loops can share the same pacing
/// shape. When the clock cannot start (headless CI, no display), callers keep
/// their timed sleep and stay functional.
extern "C" fn native_frame_clock_init(ns_view : UInt64) -> Int32 = "mbw_frame_clock_init"

///|
extern "C" fn native_frame_clock_wait(timeout_ms : Int32) -> Int32 = "mbw_frame_clock_wait"

///|
extern "C" fn native_frame_clock_shutdown() -> Unit = "mbw_frame_clock_shutdown"

///|
extern "C" fn native_frame_clock_display_id() -> UInt32 = "mbw_frame_clock_display_id"

///|
extern "C" fn native_frame_clock_refresh_millihz() -> Int32 = "mbw_frame_clock_refresh_millihz"

///|
/// Start the display clock for `window`'s screen.
///
/// Returns whether the clock is running. A window that is not attached to a
/// screen falls back to the main display; a headless environment returns
/// `false` and the caller keeps its timed sleep.
pub fn host_vsync_init(window : Window) -> Bool {
  let view = try {
    window.content_view_handle()
  } catch {
    _ => (0 : UInt64)
  }
  host_vsync_init_handle(view)
}

///|
/// Start the clock from a raw content-view handle. Tests use this to exercise
/// the main-display fallback without constructing a window.
fn host_vsync_init_handle(ns_view : UInt64) -> Bool {
  native_frame_clock_init(ns_view) != 0
}

///|
/// Block until the next display refresh, or until `timeout_ms` elapses.
///
/// Returns whether the wait ended on a refresh. A refresh that already arrived
/// while the previous frame was produced returns immediately, so a slow frame
/// does not accumulate a backlog of stale ticks.
pub fn host_wait_for_vsync(timeout_ms : Int32) -> Bool {
  native_frame_clock_wait(timeout_ms) != 0
}

///|
/// Stop and release the display clock. Idempotent.
pub fn host_vsync_shutdown() -> Unit {
  native_frame_clock_shutdown()
}

///|
/// Display currently bound to the clock, or zero when it is stopped. Exposed for
/// host diagnostics; pacing decisions must not depend on it.
pub fn host_vsync_display_id() -> UInt32 {
  native_frame_clock_display_id()
}

///|
/// Nominal refresh rate of the bound display in millihertz, or zero when the
/// clock is stopped. Frame diagnostics use it to classify slow frames.
pub fn host_vsync_refresh_millihz() -> Int32 {
  native_frame_clock_refresh_millihz()
}
