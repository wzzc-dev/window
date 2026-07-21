///|
extern "C" fn mbw_android_host_on_create() -> Unit = "mbw_android_host_on_create"

///|
extern "C" fn mbw_android_host_on_resume() -> Unit = "mbw_android_host_on_resume"

///|
extern "C" fn mbw_android_host_on_surface_init(
  handle : UInt64,
  token : UInt64,
  width : Int,
  height : Int,
  scale : Double,
) -> Unit = "mbw_android_host_on_surface_init"

///|
extern "C" fn mbw_android_host_on_pointer_moved(x : Double, y : Double) -> Unit = "mbw_android_host_on_pointer_moved"

///|
extern "C" fn mbw_android_host_on_surface_term() -> Unit = "mbw_android_host_on_surface_term"

///|
extern "C" fn mbw_android_host_on_stop() -> Unit = "mbw_android_host_on_stop"

///|
extern "C" fn mbw_android_host_on_destroy() -> Unit = "mbw_android_host_on_destroy"

///|
test "android_native_bridge_drives_host_queue" {
  host_reset_for_test()
  let event_loop = EventLoop::new()
  let app = HostSimApp::new()
  mbw_android_host_on_create()
  mbw_android_host_on_resume()
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("resumed"))
  mbw_android_host_on_surface_init(0x11UL, 0x22UL, 640, 480, 2.0)
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("can_create_surfaces"))
  let window = match app.window.val {
    Some(w) => w
    None => fail("window missing")
  }
  assert_eq(window.native_window_handle(), 0x11UL)
  mbw_android_host_on_pointer_moved(1.0, 2.0)
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("pointer_moved"))
  mbw_android_host_on_surface_term()
  mbw_android_host_on_stop()
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("destroy_surfaces"))
  assert_true(app.has("suspended"))
  mbw_android_host_on_destroy()
  match event_loop.pump_app_events(None, app) {
    Exit(_) => ()
    Continue => fail("expected exit")
  }
  event_loop.drop()
}
