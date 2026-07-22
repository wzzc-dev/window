///|
test "linux_moui_critical_api_symbols_compile" {
  // Ensure MoUI-critical symbols remain present on the Linux backend surface.
  // Runtime Wayland evidence remains matching-host (see docs/platform-gaps.md).
  let _ = @core.WindowAttributes::default().with_title("linux-critical")
  // These are type-level references used by MoUI handlers.
  let _present = Window::present_rgba_pixels
  let _pre = Window::pre_present_notify
  let _ime = Window::request_ime_update
  let _redraw = Window::request_redraw
  let _scale = Window::scale_factor
  let _surface = Window::surface_size
  let _cursor = Window::set_cursor
  let _icon = Window::set_cursor_icon
  assert_true(true)
}
