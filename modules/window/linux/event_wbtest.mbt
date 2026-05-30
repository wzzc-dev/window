///|
struct RecordingApp {
  events : Array[@core.WindowEvent]
  mut proxy_wake_count : Int
}

///|
pub impl ApplicationHandler for RecordingApp with window_event(
  self,
  _event_loop,
  _window_id,
  event,
) {
  self.events.push(event)
}

///|
pub impl ApplicationHandler for RecordingApp with proxy_wake_up(
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
fn assert_keyboard_character_text(
  event : @core.WindowEvent,
  expected_key : String,
  expected_text : String?,
) -> Unit raise {
  match event {
    @core.WindowEvent::KeyboardInput(_, key_event, false) => {
      match key_event.logical_key() {
        @core.Key::Character(key) => inspect(key, content=expected_key)
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
  app_state_set_control_flow(@core.ControlFlow::Poll)
  assert_eq(app_state_control_flow(), @core.ControlFlow::Poll)
  app_state_set_control_flow(@core.ControlFlow::WaitUntil(1234L))
  assert_eq(app_state_control_flow(), @core.ControlFlow::WaitUntil(1234L))
}

///|
test "linux dispatch maps resize pointer key and redraw" {
  reset_test_state()
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 42
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
  assert_true(app.events[0] is @core.WindowEvent::SurfaceResized(_))
  assert_true(app.events[1] is @core.WindowEvent::PointerMoved(_, _, _, _))
  match app.events[2] {
    @core.WindowEvent::PointerButton(
      _,
      @core.ElementState::Pressed,
      position,
      true,
      @core.ButtonSource::Mouse(@core.MouseButton::Left)
    ) => {
      assert_eq(position.x(), 12.0)
      assert_eq(position.y(), 34.0)
    }
    _ => fail("expected pointer button with native coordinates")
  }
  assert_keyboard_character_text(app.events[3], "a", Some("a"))
  assert_true(app.events[4] is @core.WindowEvent::RedrawRequested)
}

///|
test "linux key dispatch includes basic text and shift state" {
  reset_test_state()
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 42
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 42L)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 30L)
  assert_eq(app.events.length(), 3)
  match app.events[0] {
    @core.WindowEvent::ModifiersChanged(modifiers) => {
      assert_true(modifiers.shift_key())
      assert_false(modifiers.control_key())
    }
    _ => fail("expected shift modifiers changed")
  }
  assert_keyboard_character_text(app.events[2], "A", Some("A"))
}

///|
test "linux control shortcuts do not emit insertable text" {
  reset_test_state()
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 42
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 29L)
  dispatch_native_input_event(raw_id, linux_event_key_down, 0, 0, 0, 46L)
  assert_eq(app.events.length(), 3)
  match app.events[0] {
    @core.WindowEvent::ModifiersChanged(modifiers) => {
      assert_true(modifiers.control_key())
      assert_false(modifiers.shift_key())
    }
    _ => fail("expected control modifiers changed")
  }
  assert_keyboard_character_text(app.events[2], "c", None)
}

///|
test "linux dispatch maps proxy wake" {
  reset_test_state()
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  dispatch_native_window_event(linux_event_proxy_wake, 0, 0, 0, 0, 0.0)
  assert_eq(app.proxy_wake_count, 1)
}
