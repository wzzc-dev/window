///|
test "ios_present_rgba_and_clear_color_smoke" {
  host_reset_for_test()
  host_push(Start)
  host_push(Resume)
  host_push(SurfaceInit(0xABCUL, 0UL, 4, 4, 1.0))
  let event_loop = EventLoop::new()
  let app = HostSimApp::new()
  ignore(event_loop.pump_app_events(None, app))
  let window = match app.window.val {
    Some(w) => w
    None => fail("window required")
  }
  assert_eq(window.view_handle(), 0xABCUL)
  let pixels = Bytes::make(64, (255 : Int).to_byte())
  assert_eq(window.present_rgba_pixels(4, 4, 16, pixels), 0)
  assert_eq(
    window.clear_color(
      (0 : Int).to_byte(),
      (128 : Int).to_byte(),
      (255 : Int).to_byte(),
      (255 : Int).to_byte(),
    ),
    0,
  )
  window.pre_present_notify()
  event_loop.drop()
}
