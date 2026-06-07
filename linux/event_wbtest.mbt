///|
struct RecordingApp {
  events : Array[@core.WindowEvent]
  mut proxy_wake_count : Int
}

///|
pub impl ApplicationHandler for RecordingApp with fn window_event(
  self,
  _event_loop,
  _window_id,
  event,
) {
  self.events.push(event)
}

///|
pub impl ApplicationHandler for RecordingApp with fn proxy_wake_up(
  self,
  _event_loop,
) {
  self.proxy_wake_count = self.proxy_wake_count + 1
}

///|
fn reset_test_state() -> Unit {
  app_state_runtime.val = AppStateRuntime::new()
  event_loop_global_created.val = false
}

///|
fn test_active_loop() -> ActiveEventLoop {
  { inner: { context: (0 : Int).to_uint64(), wake_fd: -1 } }
}

///|
fn begin_recording() -> RecordingApp {
  reset_test_state()
  let app = { events: [], proxy_wake_count: 0 }
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, test_active_loop())
  app
}

///|
fn register_test_window_entry(raw_id : Int, handle : UInt64) -> Unit {
  app_state_register_window_entry({
    raw_id,
    handle,
    title: "test",
    visible: true,
    resizable: true,
    cursor: Icon(Default),
    fullscreen: None,
    surface_size: PhysicalSize(1, 1),
    scale_factor: 1.0,
  })
}

///|
fn assert_keyboard_character_text(
  event : @core.WindowEvent,
  expected_key : String,
  expected_text : String?,
) -> Unit raise {
  match event {
    KeyboardInput(_, key_event, false) => {
      match key_event.logical_key() {
        Character(key) => inspect(key, content=expected_key)
        _ => fail("expected character logical key")
      }
      match (key_event.text(), expected_text) {
        (Some(actual), Some(expected)) => inspect(actual, content=expected)
        (None, None) => ()
        _ => fail("unexpected key text")
      }
    }
    _ => fail("expected keyboard input")
  }
}

///|
test "linux app state allocates window ids and stores control flow" {
  reset_test_state()
  assert_eq(app_state_next_window_id(), 1)
  assert_eq(app_state_next_window_id(), 2)
  app_state_set_control_flow(Poll)
  assert_eq(app_state_control_flow(), Poll)
  app_state_set_control_flow(WaitUntil(1234L))
  assert_eq(app_state_control_flow(), WaitUntil(1234L))
}

///|
test "linux event loop drop cleanup clears app state context windows and redraws" {
  reset_test_state()
  let context = 0x1234UL
  let raw_id = 11
  app_state_set_context(context)
  register_test_window_entry(raw_id, 77UL)
  app_state_queue_redraw(raw_id)
  assert_true(app_state_window_handle(raw_id) is Some(_))
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 1)
  app_state_clear_context_windows(context)
  assert_eq(app_state_context(), 0UL)
  assert_true(app_state_window_handle(raw_id) == None)
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 0)
}

///|
test "linux window runtime cleanup clears app state handle and redraws" {
  let app = begin_recording()
  let active_loop = test_active_loop()
  let raw_id = 12
  register_test_window_entry(raw_id, 77UL)
  app_state_runtime.val.pending_redraw_window_ids.push(raw_id)
  assert_true(app_state_window_handle(raw_id) is Some(_))
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 1)
  app_state_clear_window_runtime_state(raw_id)
  assert_true(app_state_window_handle(raw_id) == None)
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 0)
  app_state_dispatch_redraws(app, active_loop)
  assert_eq(app.events.length(), 0)
}

///|
test "linux dispatch maps resize pointer key and redraw" {
  let app = begin_recording()
  let active_loop = test_active_loop()
  let raw_id = 42
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_window_event(linux_event_configure, raw_id, 320, 200, 0, 0.0)
  dispatch_native_input_event(raw_id, linux_event_pointer_move, 12, 34, 0, 0L)
  dispatch_native_input_event(
    raw_id, linux_event_pointer_down, 12, 34, 0x110, 0L,
  )
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 30L)
  app_state_queue_redraw(raw_id)
  app_state_queue_redraw(raw_id)
  app_state_dispatch_redraws(app, active_loop)
  assert_eq(app.events.length(), 5)
  assert_true(app.events[0] is SurfaceResized(_))
  assert_true(app.events[1] is PointerMoved(_, _, _, _))
  match app.events[2] {
    PointerButton(_, Pressed, position, true, Mouse(Left)) => {
      assert_eq(position.x(), 12.0)
      assert_eq(position.y(), 34.0)
    }
    _ => fail("expected pointer button with native coordinates")
  }
  assert_keyboard_character_text(app.events[3], "a", Some("a"))
  assert_true(app.events[4] is RedrawRequested)
}

///|
test "linux key dispatch includes basic text and shift state" {
  let app = begin_recording()
  let raw_id = 42
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 42L)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 30L)
  assert_eq(app.events.length(), 3)
  match app.events[0] {
    ModifiersChanged(modifiers) => {
      assert_true(modifiers.shift_key())
      assert_false(modifiers.control_key())
    }
    _ => fail("expected shift modifiers changed")
  }
  assert_keyboard_character_text(app.events[2], "A", Some("A"))
}

///|
test "linux control shortcuts do not emit insertable text" {
  let app = begin_recording()
  let raw_id = 42
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 29L)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 46L)
  assert_eq(app.events.length(), 3)
  match app.events[0] {
    ModifiersChanged(modifiers) => {
      assert_true(modifiers.control_key())
      assert_false(modifiers.shift_key())
    }
    _ => fail("expected control modifiers changed")
  }
  assert_keyboard_character_text(app.events[2], "c", None)
}

///|
test "linux key dispatch preserves right modifier locations" {
  let app = begin_recording()
  let raw_id = 42
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 54L)
  assert_eq(app.events.length(), 2)
  match app.events[1] {
    KeyboardInput(_, key_event, false) => {
      assert_eq(key_event.location(), Right)
      assert_eq(
        key_event.physical_key(),
        @core.PhysicalKey::from_key_code(ShiftRight),
      )
      match key_event.logical_key() {
        Named(Shift) => ()
        _ => fail("expected right shift logical key")
      }
    }
    _ => fail("expected right shift keyboard input")
  }
}

///|
test "linux dispatch maps pointer enter leave button release and wheel" {
  let app = begin_recording()
  let raw_id = 42
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_input_event(raw_id, linux_event_pointer_enter, 10, 20, 0, 0L)
  dispatch_native_input_event(
    raw_id, linux_event_pointer_down, 12, 34, 0x111, 0L,
  )
  dispatch_native_input_event(raw_id, linux_event_pointer_up, 12, 34, 0x112, 0L)
  dispatch_native_input_event(raw_id, linux_event_wheel, -5, 9, 0, 0L)
  dispatch_native_input_event(raw_id, linux_event_pointer_leave, 0, 0, 0, 0L)
  assert_eq(app.events.length(), 5)
  match app.events[0] {
    PointerEntered(_, position, true, Mouse) => {
      assert_eq(position.x(), 10.0)
      assert_eq(position.y(), 20.0)
    }
    _ => fail("expected pointer enter")
  }
  match app.events[1] {
    PointerButton(_, Pressed, position, true, Mouse(Right)) => {
      assert_eq(position.x(), 12.0)
      assert_eq(position.y(), 34.0)
    }
    _ => fail("expected right pointer press")
  }
  match app.events[2] {
    PointerButton(_, Released, position, true, Mouse(Middle)) => {
      assert_eq(position.x(), 12.0)
      assert_eq(position.y(), 34.0)
    }
    _ => fail("expected middle pointer release")
  }
  match app.events[3] {
    MouseWheel(_, PixelDelta(delta), Moved) => {
      assert_eq(delta.x(), -5.0)
      assert_eq(delta.y(), -9.0)
    }
    _ => fail("expected pixel wheel delta")
  }
  match app.events[4] {
    PointerLeft(_, None, true, Mouse) => ()
    _ => fail("expected pointer leave without coordinates")
  }
}

///|
test "linux dispatch maps focus close destroyed and theme" {
  let app = begin_recording()
  let raw_id = 9
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_window_event(linux_event_focus, raw_id, 1, 0, 0, 0.0)
  dispatch_native_window_event(linux_event_focus, raw_id, 0, 0, 0, 0.0)
  dispatch_native_window_event(linux_event_close, raw_id, 0, 0, 0, 0.0)
  dispatch_native_window_event(41, raw_id, 0, 0, 0, 1.0)
  dispatch_native_window_event(41, raw_id, 0, 0, 0, 0.0)
  dispatch_native_window_event(linux_event_destroyed, raw_id, 0, 0, 0, 0.0)
  dispatch_native_window_event(41, raw_id, 0, 0, 0, 1.0)
  assert_eq(app.events.length(), 6)
  assert_true(app.events[0] is Focused(true))
  assert_true(app.events[1] is Focused(false))
  assert_true(app.events[2] is CloseRequested)
  assert_true(app.events[3] is ThemeChanged(Dark))
  assert_true(app.events[4] is ThemeChanged(Light))
  assert_true(app.events[5] is Destroyed)
}

///|
test "linux window dispatch ignores unregistered windows" {
  let app = begin_recording()
  let raw_id = 16
  dispatch_native_window_event(linux_event_configure, raw_id, 320, 200, 0, 0.0)
  dispatch_native_window_event(linux_event_focus, raw_id, 1, 0, 0, 0.0)
  dispatch_native_window_event(linux_event_close, raw_id, 0, 0, 0, 0.0)
  dispatch_native_window_event(linux_event_destroyed, raw_id, 0, 0, 0, 0.0)
  dispatch_native_window_event(41, raw_id, 0, 0, 0, 1.0)
  assert_eq(app.events.length(), 0)
}

///|
test "linux focus loss clears pressed modifiers" {
  let app = begin_recording()
  let raw_id = 12
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 42L)
  dispatch_native_window_event(linux_event_focus, raw_id, 0, 0, 0, 0.0)
  assert_eq(app.events.length(), 4)
  match app.events[0] {
    ModifiersChanged(modifiers) => assert_true(modifiers.shift_key())
    _ => fail("expected shift modifier press")
  }
  assert_true(app.events[2] is Focused(false))
  match app.events[3] {
    ModifiersChanged(modifiers) => assert_true(modifiers.is_empty())
    _ => fail("expected empty modifiers after focus loss")
  }
  assert_true(app_state_modifiers().is_empty())
}

///|
test "linux destroyed clears pressed modifiers" {
  let app = begin_recording()
  let active_loop = test_active_loop()
  let raw_id = 13
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 42L)
  app_state_queue_redraw(raw_id)
  assert_true(app_state_window_handle(raw_id) is Some(_))
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 1)
  dispatch_native_window_event(linux_event_destroyed, raw_id, 0, 0, 0, 0.0)
  assert_eq(app.events.length(), 4)
  match app.events[0] {
    ModifiersChanged(modifiers) => assert_true(modifiers.shift_key())
    _ => fail("expected shift modifier press")
  }
  match app.events[2] {
    ModifiersChanged(modifiers) => assert_true(modifiers.is_empty())
    _ => fail("expected empty modifiers before destroyed")
  }
  assert_true(app.events[3] is Destroyed)
  assert_true(app_state_modifiers().is_empty())
  assert_true(app_state_window_handle(raw_id) == None)
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 0)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 30L)
  dispatch_native_input_event(raw_id, linux_event_pointer_move, 12, 34, 0, 0L)
  app_state_dispatch_redraws(app, active_loop)
  assert_eq(app.events.length(), 4)
}

///|
test "linux input dispatch ignores unregistered windows" {
  let app = begin_recording()
  let raw_id = 15
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 42L)
  dispatch_native_input_event(raw_id, linux_event_pointer_move, 12, 34, 0, 0L)
  assert_eq(app.events.length(), 0)
  assert_true(app_state_modifiers().is_empty())
}

///|
test "linux redraw queue ignores unregistered windows" {
  let app = begin_recording()
  let active_loop = test_active_loop()
  let raw_id = 14
  app_state_queue_redraw(raw_id)
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 0)
  register_test_window_entry(raw_id, 0UL)
  app_state_queue_redraw(raw_id)
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 1)
  app_state_clear_window_runtime_state(raw_id)
  app_state_queue_redraw(raw_id)
  assert_eq(app_state_runtime.val.pending_redraw_window_ids.length(), 0)
  app_state_dispatch_redraws(app, active_loop)
  assert_eq(app.events.length(), 0)
}

///|
test "linux dispatch normalizes empty configure sizes" {
  let app = begin_recording()
  let raw_id = 7
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_window_event(linux_event_configure, raw_id, 0, -20, 0, 0.0)
  assert_eq(app.events.length(), 1)
  match app.events[0] {
    SurfaceResized(size) => {
      assert_eq(size.width(), 1)
      assert_eq(size.height(), 1)
    }
    _ => fail("expected normalized surface resize")
  }
}

///|
test "linux dispatch tracks modifier release by key family" {
  let app = begin_recording()
  let raw_id = 10
  register_test_window_entry(raw_id, 0UL)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 42L)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 54L)
  dispatch_native_input_event(raw_id, linux_event_key_up, 0, 0, 0, 42L)
  dispatch_native_input_event(raw_id, linux_event_key_up, 0, 0, 0, 54L)
  assert_eq(app.events.length(), 8)
  match app.events[0] {
    ModifiersChanged(modifiers) => {
      assert_true(modifiers.shift_key())
      assert_true(modifiers.lshift_state() is Pressed)
      assert_true(modifiers.rshift_state() is Unknown)
    }
    _ => fail("expected left shift modifier")
  }
  match app.events[2] {
    ModifiersChanged(modifiers) => {
      assert_true(modifiers.shift_key())
      assert_true(modifiers.lshift_state() is Pressed)
      assert_true(modifiers.rshift_state() is Pressed)
    }
    _ => fail("expected both shift modifiers")
  }
  match app.events[4] {
    ModifiersChanged(modifiers) => {
      assert_true(modifiers.shift_key())
      assert_true(modifiers.lshift_state() is Unknown)
      assert_true(modifiers.rshift_state() is Pressed)
    }
    _ => fail("expected right shift to keep shift active")
  }
  match app.events[6] {
    ModifiersChanged(modifiers) => {
      assert_true(modifiers.is_empty())
      assert_true(modifiers.lshift_state() is Unknown)
      assert_true(modifiers.rshift_state() is Unknown)
    }
    _ => fail("expected empty shift modifiers")
  }
  match app.events[7] {
    KeyboardInput(_, key_event, false) => {
      assert_eq(key_event.state(), Released)
      match key_event.logical_key() {
        Named(Shift) => ()
        _ => fail("expected released shift key")
      }
    }
    _ => fail("expected final shift release")
  }
  assert_true(app_state_modifiers().is_empty())
}

///|
test "linux dispatch maps proxy wake" {
  let app = begin_recording()
  dispatch_native_window_event(linux_event_proxy_wake, 0, 0, 0, 0, 0.0)
  assert_eq(app.proxy_wake_count, 1)
}

///|
test "linux dispatch ignores invalid raw ids except proxy wake" {
  let app = begin_recording()
  let active_loop = test_active_loop()
  dispatch_native_window_event(linux_event_configure, 0, 320, 200, 0, 0.0)
  dispatch_native_window_event(linux_event_redraw, 0, 0, 0, 0, 0.0)
  dispatch_native_window_event(linux_event_destroyed, 0, 0, 0, 0, 0.0)
  dispatch_native_window_event(41, 0, 0, 0, 0, 1.0)
  dispatch_native_input_event(0, linux_event_key_down, 0, 0, 0, 42L)
  dispatch_native_input_event(0, linux_event_pointer_move, 12, 34, 0, 0L)
  app_state_dispatch_redraws(app, active_loop)
  assert_eq(app.events.length(), 0)
  assert_true(app_state_modifiers().is_empty())
  dispatch_native_window_event(linux_event_proxy_wake, 0, 0, 0, 0, 0.0)
  assert_eq(app.proxy_wake_count, 1)
}
