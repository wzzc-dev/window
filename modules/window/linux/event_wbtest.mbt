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

///|
test "linux focus updates has_focus state" {
  reset_test_state()
  let raw_id = 9101
  app_state_register_window_entry({
    raw_id,
    handle: 1UL,
    title: "focus",
    visible: true,
    resizable: true,
    cursor: @core.Cursor::Icon(@core.CursorIcon::Default),
    fullscreen: None,
    focused: false,
    surface_size: @dpi.PhysicalSize::PhysicalSize(1, 1),
    scale_factor: 1.0,
  })
  assert_false(app_state_window_focused(raw_id))
  dispatch_native_window_event(linux_event_focus, raw_id, 1, 0, 0, 0.0)
  assert_true(app_state_window_focused(raw_id))
  dispatch_native_window_event(linux_event_focus, raw_id, 0, 0, 0, 0.0)
  assert_false(app_state_window_focused(raw_id))
  app_state_unregister_window(raw_id)
}

///|
test "linux clipboard and drag-drop APIs are safe without a Wayland context" {
  reset_test_state()
  assert_false(clipboard_available())
  assert_true(read_clipboard_text() is None)
  assert_false(write_clipboard_text("clipboard text"))
  assert_false(drag_drop_available())
}

///|
test "linux wheel dispatch preserves native delta signs" {
  reset_test_state()
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 42
  // The native layer emits (x, y) deltas using the window library convention:
  // positive vertical = scroll up. dispatch must pass them through unchanged.
  dispatch_native_input_event(raw_id, linux_event_wheel, 0, -120, 0, 0L)
  dispatch_native_input_event(raw_id, linux_event_wheel, 0, 120, 0, 0L)
  dispatch_native_input_event(raw_id, linux_event_wheel, -30, 0, 0, 0L)
  assert_eq(app.events.length(), 3)
  match app.events[0] {
    @core.WindowEvent::MouseWheel(
      _,
      @core.MouseScrollDelta::PixelDelta(position),
      @core.TouchPhase::Moved
    ) => {
      assert_eq(position.x(), 0.0)
      assert_eq(position.y(), -120.0)
    }
    _ => fail("expected mouse wheel event")
  }
  match app.events[1] {
    @core.WindowEvent::MouseWheel(
      _,
      @core.MouseScrollDelta::PixelDelta(position),
      @core.TouchPhase::Moved
    ) => {
      assert_eq(position.x(), 0.0)
      assert_eq(position.y(), 120.0)
    }
    _ => fail("expected mouse wheel event")
  }
  match app.events[2] {
    @core.WindowEvent::MouseWheel(
      _,
      @core.MouseScrollDelta::PixelDelta(position),
      @core.TouchPhase::Moved
    ) => {
      assert_eq(position.x(), -30.0)
      assert_eq(position.y(), 0.0)
    }
    _ => fail("expected mouse wheel event")
  }
}

///|
test "linux dispatch maps drag lifecycle events" {
  reset_test_state()
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 42
  dispatch_native_input_event(raw_id, linux_event_drag_enter, 12, 34, 0, 0L)
  dispatch_native_input_event(raw_id, linux_event_drag_move, 13, 35, 0, 0L)
  dispatch_native_input_event(raw_id, linux_event_drag_drop, 14, 36, 0, 0L)
  dispatch_native_input_event(raw_id, linux_event_drag_leave, 15, 37, 0, 0L)
  assert_eq(app.events.length(), 4)
  match app.events[0] {
    @core.WindowEvent::DragEntered(paths, position) => {
      assert_eq(paths.length(), 0)
      assert_eq(position.x(), 12.0)
      assert_eq(position.y(), 34.0)
    }
    _ => fail("expected drag entered")
  }
  match app.events[1] {
    @core.WindowEvent::DragMoved(position) => {
      assert_eq(position.x(), 13.0)
      assert_eq(position.y(), 35.0)
    }
    _ => fail("expected drag moved")
  }
  match app.events[2] {
    @core.WindowEvent::DragDropped(paths, position) => {
      assert_eq(paths.length(), 0)
      assert_eq(position.x(), 14.0)
      assert_eq(position.y(), 36.0)
    }
    _ => fail("expected drag dropped")
  }
  match app.events[3] {
    @core.WindowEvent::DragLeft(Some(position)) => {
      assert_eq(position.x(), 15.0)
      assert_eq(position.y(), 37.0)
    }
    _ => fail("expected drag left")
  }
}
