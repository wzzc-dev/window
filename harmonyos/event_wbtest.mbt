///|
test "harmonyos_create_window_and_bind_surface" {
  let event_loop = EventLoop::new()
  let attrs = @core.WindowAttributes::default().with_title("harmonyos smoke")
  let platform = WindowAttributesHarmonyOS::default()
    .with_surface_handle(0x1000UL)
    .with_surface_token(0x2000UL)
    .with_size(720, 1280)
    .with_scale_factor(2.5)
  let window = Window::new_with_harmonyos_attributes(
    event_loop, attrs, platform,
  )
  assert_eq(window.window_handle(), 0x1000UL)
  window.bind_surface(0x3000UL, 0x4000UL, 800, 1600, 3.0)
  assert_eq(window.window_handle(), 0x3000UL)
  assert_eq(window.surface_size().width, 800)
  assert_eq(window.scale_factor(), 3.0)
  window.drop()
  event_loop.drop()
}
