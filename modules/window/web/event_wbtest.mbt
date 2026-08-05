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
fn test_active_loop() -> ActiveEventLoop {
  { inner: { _unit: () } }
}

///|
test "web dispatch maps resize pointer key and redraw" {
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 42
  web_dispatch_event(web_event_resize, raw_id, 320, 200, 1.0, "")
  web_dispatch_event(web_event_pointer_move, raw_id, 12, 34, 0.0, "")
  web_dispatch_event(web_event_key_down, raw_id, 0, 0, 0.0, "a")
  app_state_queue_redraw(raw_id)
  app_state_queue_redraw(raw_id)
  app_state_dispatch_redraws(app, active_loop)
  assert_eq(app.events.length(), 4)
  assert_true(app.events[0] is @core.WindowEvent::SurfaceResized(_))
  assert_true(app.events[1] is @core.WindowEvent::PointerMoved(_, _, _, _))
  match app.events[2] {
    @core.WindowEvent::KeyboardInput(_, event, false) =>
      match event.text() {
        Some("a") => ()
        _ => fail("expected character key text")
      }
    _ => fail("expected keyboard input")
  }
  assert_true(app.events[3] is @core.WindowEvent::RedrawRequested)
}

///|
test "web dispatch takes the browser supplied scale factor" {
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 43
  app_state_register_window_entry({
    raw_id,
    title: "",
    visible: true,
    resizable: true,
    cursor: @core.Cursor::Icon(@core.CursorIcon::Default),
    fullscreen: None,
    focused: false,
    scale_factor: 1.0,
  })
  web_dispatch_event(web_event_resize, raw_id, 320, 200, 2.0, "")
  inspect(app_state_window_scale_factor(raw_id), content="2")
  assert_eq(app.events.length(), 2)
  match app.events[0] {
    ScaleFactorChanged(2.0, _) => ()
    _ => fail("expected the scale factor sent by the browser host")
  }
  assert_true(app.events[1] is SurfaceResized(_))
}

///|
test "web dispatch maps proxy wake" {
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  web_dispatch_event(web_event_proxy_wake, 0, 0, 0, 0.0, "")
  assert_eq(app.proxy_wake_count, 1)
}

///|
test "web dispatch maps ime composition lifecycle" {
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 7
  web_dispatch_event(web_event_ime_start, raw_id, 0, 0, 0.0, "")
  web_dispatch_event(web_event_ime_preedit, raw_id, 0, 2, 0.0, "ni")
  web_dispatch_event(web_event_ime_commit, raw_id, 0, 0, 0.0, "你")
  assert_eq(app.events.length(), 3)
  assert_true(app.events[0] is @core.WindowEvent::Ime(@core.Ime::Enabled))
  match app.events[1] {
    @core.WindowEvent::Ime(@core.Ime::Preedit("ni", Some({ start: 0, end: 2 }))) =>
      ()
    _ => fail("expected ime preedit")
  }
  match app.events[2] {
    @core.WindowEvent::Ime(@core.Ime::Commit("你")) => ()
    _ => fail("expected ime commit")
  }
}

///|
test "web wheel dispatch preserves native delta signs" {
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 42
  // The browser host emits (x, y) deltas using the window library convention:
  // positive vertical = scroll up. dispatch must pass them through unchanged.
  web_dispatch_event(web_event_wheel, raw_id, 0, -120, 0.0, "")
  web_dispatch_event(web_event_wheel, raw_id, 0, 120, 0.0, "")
  web_dispatch_event(web_event_wheel, raw_id, -30, 0, 0.0, "")
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
test "web dispatch maps browser file drag drop lifecycle" {
  let app = { events: [], proxy_wake_count: 0 }
  let active_loop = test_active_loop()
  app_state_set_running(true)
  app_state_set_dispatch_handler(app, active_loop)
  let raw_id = 9
  web_dispatch_event(
    web_event_drag_enter, raw_id, 12, 24, 0.0, "note.md\nimage.png",
  )
  web_dispatch_event(web_event_drag_move, raw_id, 16, 32, 0.0, "")
  web_dispatch_event(web_event_drag_drop, raw_id, 20, 40, 0.0, "note.md")
  web_dispatch_event(web_event_drag_leave, raw_id, 22, 44, 0.0, "")
  assert_eq(app.events.length(), 4)
  match app.events[0] {
    @core.WindowEvent::DragEntered(paths, { x: 12.0, y: 24.0 }) => {
      inspect(paths.length(), content="2")
      inspect(paths[0], content="note.md")
      inspect(paths[1], content="image.png")
    }
    _ => fail("expected drag enter")
  }
  match app.events[1] {
    @core.WindowEvent::DragMoved({ x: 16.0, y: 32.0 }) => ()
    _ => fail("expected drag move")
  }
  match app.events[2] {
    @core.WindowEvent::DragDropped(paths, { x: 20.0, y: 40.0 }) => {
      inspect(paths.length(), content="1")
      inspect(paths[0], content="note.md")
    }
    _ => fail("expected drag drop")
  }
  match app.events[3] {
    @core.WindowEvent::DragLeft(Some({ x: 22.0, y: 44.0 })) => ()
    _ => fail("expected drag leave")
  }
}
