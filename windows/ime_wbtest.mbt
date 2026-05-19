///|
test "windows window ime request state supports enable update disable" {
  let window = Window::{
    id: @core.WindowId::from_raw(1),
    hwnd: 1UL,
    cursor_state: @core.Cursor::Icon(@core.CursorIcon::Default),
    fullscreen_state: None,
    ime_capabilities_state: None,
    ime_surrounding_text_state: None,
    ime_cursor_area_position_state: @dpi.PhysicalPosition::new(0, 0),
    ime_cursor_area_size_state: @dpi.PhysicalSize::new(1, 1),
    is_decorated_state: true,
    is_maximized_state: false,
    is_visible_state: true,
    is_resizable_state: true,
    is_cursor_visible_state: true,
    is_cursor_hittest_state: true,
    is_transparent_state: false,
    is_blurred_state: false,
    scale_factor_state: 1.0,
    saved_window_rect_left: 0,
    saved_window_rect_top: 0,
    saved_window_rect_right: 0,
    saved_window_rect_bottom: 0,
    saved_window_style: 0,
    saved_window_ex_style: 0,
  }
  let surrounding = @core.ImeSurroundingText::new("你好", 6, 6) catch {
    _ => fail("expected surrounding text")
  }
  let position = @dpi.LogicalPosition::new(12.0, 18.0).into_position()
  let size = @dpi.LogicalSize::new(2.0, 20.0).into_size()
  let data = @core.ImeRequestData::default()
    .with_surrounding_text(surrounding)
    .with_cursor_area(position, size)
  let enable = @core.ImeEnableRequest::new(
    @core.ImeCapabilities::default().with_surrounding_text().with_cursor_area(),
    data,
  )
  guard enable is Some(enable) else { fail("expected enable request") }
  window.request_ime_update(@core.ImeRequest::Enable(enable)) catch {
    _ => fail("expected enable")
  }
  inspect(window.ime_allowed(), content="true")
  match window.ime_surrounding_text() {
    Some(value) => inspect(value.text(), content="你好")
    None => fail("expected surrounding text")
  }
  assert_true(
    window.ime_cursor_area_position() == @dpi.PhysicalPosition::new(12, 18),
  )
  assert_true(window.ime_cursor_area_size() == @dpi.PhysicalSize::new(2, 20))
  window.request_ime_update(@core.ImeRequest::Disable) catch {
    _ => fail("expected disable")
  }
  inspect(window.ime_allowed(), content="false")
  assert_true(window.ime_cursor_area_size() == @dpi.PhysicalSize::new(1, 1))
}
