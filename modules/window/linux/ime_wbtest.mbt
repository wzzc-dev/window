///|
test "linux window ime request state supports enable update disable" {
  let window = Window::{
    id: @core.WindowId::from_raw(1),
    handle: 1UL,
    cursor_visible_state: true,
    cursor_hittest_state: true,
    transparent_state: false,
    blur_state: false,
    decorated_state: true,
    minimized_state: false,
    maximized_state: false,
    enabled_buttons_state: @core.WindowButtons::all(),
    window_level_state: Normal,
    theme_state: None,
    ime_capabilities_state: None,
    ime_hints_state: @core.ImeHint::none(),
    ime_purpose_state: Normal,
    ime_surrounding_text_state: None,
    ime_cursor_area_position_state: PhysicalPosition(0, 0),
    ime_cursor_area_size_state: PhysicalSize(1, 1),
  }
  let surrounding = @core.ImeSurroundingText::ImeSurroundingText("moui", 4, 4) catch {
    _ => fail("expected surrounding text")
  }
  let position : @dpi.Position = @dpi.LogicalPosition::LogicalPosition(
    12.0, 18.0,
  ).into_position()
  let size : @dpi.Size = @dpi.LogicalSize::LogicalSize(2.0, 20.0).into_size()
  let data = @core.ImeRequestData::default()
    .with_hint_and_purpose(@core.ImeHint::completion(), Email)
    .with_surrounding_text(surrounding)
    .with_cursor_area(position, size)
  let enable = @core.ImeEnableRequest::from_capabilities(
    @core.ImeCapabilities::default()
    .with_hint_and_purpose()
    .with_surrounding_text()
    .with_cursor_area(),
    data,
  )
  guard enable is Some(enable) else { fail("expected enable request") }
  window.request_ime_update(Enable(enable)) catch {
    _ => fail("expected enable")
  }
  inspect(window.ime_allowed(), content="true")
  match window.ime_capabilities() {
    Some(capabilities) => {
      assert_true(capabilities.hint_and_purpose())
      assert_true(capabilities.surrounding_text())
      assert_true(capabilities.cursor_area())
    }
    None => fail("expected capabilities")
  }
  assert_true(window.ime_hints().contains(@core.ImeHint::completion()))
  assert_eq(window.ime_purpose(), Email)
  match window.ime_surrounding_text() {
    Some(value) => inspect(value.text(), content="moui")
    None => fail("expected surrounding text")
  }
  assert_true(window.ime_cursor_area_position() == PhysicalPosition(12, 18))
  assert_true(window.ime_cursor_area_size() == PhysicalSize(2, 20))
  let updated_surrounding = @core.ImeSurroundingText::ImeSurroundingText(
    "linux", 5, 5,
  ) catch {
    _ => fail("expected updated surrounding text")
  }
  let updated_position : @dpi.Position = @dpi.LogicalPosition::LogicalPosition(
    20.0, 22.0,
  ).into_position()
  let updated_size : @dpi.Size = @dpi.LogicalSize::LogicalSize(3.0, 10.0).into_size()
  window.request_ime_update(
    Update(
      @core.ImeRequestData::default()
      .with_hint_and_purpose(@core.ImeHint::spellcheck(), Url)
      .with_surrounding_text(updated_surrounding)
      .with_cursor_area(updated_position, updated_size),
    ),
  ) catch {
    _ => fail("expected update")
  }
  assert_true(window.ime_hints().contains(@core.ImeHint::spellcheck()))
  assert_eq(window.ime_purpose(), Url)
  match window.ime_surrounding_text() {
    Some(value) => inspect(value.text(), content="linux")
    None => fail("expected updated surrounding text")
  }
  assert_true(window.ime_cursor_area_position() == PhysicalPosition(20, 22))
  assert_true(window.ime_cursor_area_size() == PhysicalSize(3, 10))
  window.request_ime_update(Disable) catch {
    _ => fail("expected disable")
  }
  inspect(window.ime_allowed(), content="false")
  assert_true(window.ime_capabilities() == None)
  assert_true(window.ime_surrounding_text() == None)
  assert_true(window.ime_cursor_area_size() == PhysicalSize(1, 1))
}

///|
test "linux window ime request rejects invalid state transitions" {
  let window = Window::{
    id: @core.WindowId::from_raw(2),
    handle: 1UL,
    cursor_visible_state: true,
    cursor_hittest_state: true,
    transparent_state: false,
    blur_state: false,
    decorated_state: true,
    minimized_state: false,
    maximized_state: false,
    enabled_buttons_state: @core.WindowButtons::all(),
    window_level_state: Normal,
    theme_state: None,
    ime_capabilities_state: None,
    ime_hints_state: @core.ImeHint::none(),
    ime_purpose_state: Normal,
    ime_surrounding_text_state: None,
    ime_cursor_area_position_state: PhysicalPosition(0, 0),
    ime_cursor_area_size_state: PhysicalSize(1, 1),
  }
  try {
    window.request_ime_update(Update(@core.ImeRequestData::default()))
    fail("expected NotEnabled")
  } catch {
    @core.ImeRequestError::NotEnabled => ()
    _ => fail("expected NotEnabled")
  }
  let enable = @core.ImeEnableRequest::from_capabilities(
    @core.ImeCapabilities::default(),
    @core.ImeRequestData::default(),
  )
  guard enable is Some(enable) else { fail("expected empty enable request") }
  window.request_ime_update(Enable(enable)) catch {
    _ => fail("expected enable")
  }
  try {
    window.request_ime_update(Enable(enable))
    fail("expected AlreadyEnabled")
  } catch {
    @core.ImeRequestError::AlreadyEnabled => ()
    _ => fail("expected AlreadyEnabled")
  }
}
