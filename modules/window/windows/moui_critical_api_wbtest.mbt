///|
/// Compile-time / smoke coverage for MoUI-critical Window methods on Windows.
test "windows_moui_critical_window_api_shape" {
  // Construct a synthetic window state object used by whitebox IME tests.
  let window = Window::{
    id: @core.WindowId::from_raw(1),
    hwnd: 1UL,
    cursor_state: Icon(Default),
    fullscreen_state: None,
    ime_capabilities_state: None,
    ime_hints_state: @core.ImeHint::none(),
    ime_purpose_state: Normal,
    ime_surrounding_text_state: None,
    ime_cursor_area_position_state: PhysicalPosition(0, 0),
    ime_cursor_area_size_state: PhysicalSize(1, 1),
    is_decorated_state: true,
    is_maximized_state: false,
    is_visible_state: true,
    is_resizable_state: true,
    is_cursor_visible_state: true,
    is_cursor_hittest_state: true,
    is_transparent_state: false,
    is_blurred_state: false,
    saved_window_rect_left: 0,
    saved_window_rect_top: 0,
    saved_window_rect_right: 0,
    saved_window_rect_bottom: 0,
    saved_window_style: 0,
    saved_window_ex_style: 0,
  }
  window.pre_present_notify()
  window.request_redraw()
  ignore(window.surface_size())
  ignore(window.scale_factor())
  ignore(window.cursor())
  window.set_cursor(Icon(Text))
  window.set_cursor_icon(Text)
  assert_true(window.id().into_raw() == 1)
}
