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
  web_dispatch_event(web_event_resize, raw_id, 320, 200, 0.0, "")
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
