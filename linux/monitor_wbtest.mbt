///|
fn test_window_for_monitor(handle : UInt64) -> Window {
  {
    id: @core.WindowId::from_raw(1),
    handle,
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
}

///|
test "linux monitor helpers do not fabricate monitors without a Wayland context" {
  if app_state_context() == (0 : Int).to_uint64() {
    assert_eq(available_monitors().length(), 0)
    assert_true(primary_monitor() == None)
    assert_true(current_monitor_for_window(1UL) == None)
  }
}

///|
test "linux monitor helpers normalize invalid size and scale" {
  assert_true(linux_monitor_surface_size(0, -8) == PhysicalSize(1, 1))
  assert_true(linux_monitor_surface_size(1920, 0) == PhysicalSize(1920, 1))
  assert_eq(linux_monitor_scale_factor(1.25), 1.25)
  assert_eq(linux_monitor_scale_factor(0.0), 1.0)
  assert_eq(linux_monitor_scale_factor(-2.0), 1.0)
  assert_eq(linux_monitor_scale_factor(0.0 / 0.0), 1.0)
  assert_eq(linux_monitor_scale_factor(1.0 / 0.0), 1.0)
}

///|
test "linux monitor handles preserve native output identity when available" {
  let monitors = available_monitors()
  if monitors.length() > 0 {
    let first = monitors[0]
    assert_true(first.native_id() != 0UL)
    assert_true(first.surface_size().width > 0)
    assert_true(first.surface_size().height > 0)
    assert_true(first.scale_factor() > 0.0)
    match primary_monitor() {
      Some(primary) => assert_eq(primary.native_id(), first.native_id())
      None => fail("expected primary monitor")
    }
  }
}

///|
test "linux window current monitor does not fall back without surface output" {
  let window = test_window_for_monitor(1UL)
  reset_test_state()
  assert_true(window.current_monitor() == None)
  app_state_register_window_entry({
    raw_id: 1,
    handle: 1UL,
    title: "test",
    visible: true,
    resizable: true,
    cursor: Icon(Default),
    fullscreen: None,
    focused: false,
    surface_size: PhysicalSize(1, 1),
    scale_factor: 1.0,
  })
  assert_true(window.current_monitor() == current_monitor_for_window(1UL))
}
