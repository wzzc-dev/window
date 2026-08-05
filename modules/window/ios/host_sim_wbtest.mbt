///|
struct HostSimApp {
  log : Ref[Array[String]]
  window : Ref[Window?]
}

///|
fn HostSimApp::new() -> HostSimApp {
  { log: Ref([]), window: Ref(None) }
}

///|
fn HostSimApp::push(self : HostSimApp, message : String) -> Unit {
  self.log.val.push(message)
}

///|
fn HostSimApp::has(self : HostSimApp, message : String) -> Bool {
  self.log.val.search_by(item => item == message) is Some(_)
}

///|
fn HostSimApp::has_prefix(self : HostSimApp, prefix : String) -> Bool {
  self.log.val.search_by(item => item.has_prefix(prefix)) is Some(_)
}

///|
pub impl ApplicationHandler for HostSimApp with fn new_events(
  self,
  _event_loop,
  cause,
) {
  self.push("new_events:\{cause}")
}

///|
pub impl ApplicationHandler for HostSimApp with fn resumed(self, _event_loop) {
  self.push("resumed")
}

///|
pub impl ApplicationHandler for HostSimApp with fn can_create_surfaces(
  self,
  event_loop,
) {
  self.push("can_create_surfaces")
  if self.window.val is None {
    let attrs = @core.WindowAttributes::default().with_title("hosted")
    let window = event_loop.create_window(attrs)
    self.window.val = Some(window)
    self.push("create_window_ok")
  }
}

///|
pub impl ApplicationHandler for HostSimApp with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.push("destroy_surfaces")
  match self.window.val {
    Some(window) => self.push("handle_after_destroy=\{window.view_handle()}")
    None => ()
  }
}

///|
pub impl ApplicationHandler for HostSimApp with fn suspended(self, _event_loop) {
  self.push("suspended")
}

///|
pub impl ApplicationHandler for HostSimApp with fn memory_warning(
  self,
  _event_loop,
) {
  self.push("memory_warning")
}

///|
pub impl ApplicationHandler for HostSimApp with fn window_event(
  self,
  _event_loop,
  _id,
  event,
) {
  match event {
    PointerMoved(_, _, _, _) => self.push("pointer_moved")
    PointerButton(_, _, _, _, _) => self.push("pointer_button")
    SurfaceResized(size) =>
      self.push("surface_resized:\{size.width}x\{size.height}")
    MouseWheel(_, delta, phase) => self.push("mouse_wheel:\{delta}:\{phase}")
    Ime(ime) => self.push("ime:\{ime}")
    RedrawRequested => self.push("redraw")
    _ => ()
  }
}

///|
pub impl ApplicationHandler for HostSimApp with fn about_to_wait(
  self,
  _event_loop,
) {
  self.push("about_to_wait")
}

///|
test "ios_create_window_before_surface_errors" {
  host_reset_for_test()
  let event_loop = EventLoop::new()
  let attrs = @core.WindowAttributes::default().with_title("too-early")
  let failed = try {
    ignore(event_loop.try_create_window(attrs))
    false
  } catch {
    _ => true
  }
  assert_true(failed)

  event_loop.drop()
}

///|
test "ios_host_sim_lifecycle_and_pointer" {
  host_reset_for_test()
  let event_loop = EventLoop::new()
  let app = HostSimApp::new()

  host_push(Start)
  host_push(Resume)
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("resumed"))
  assert_true(!app.has("can_create_surfaces"))

  host_push(SurfaceInit(0xA100UL, 0xB100UL, 720, 1280, 2.5))
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("can_create_surfaces"))
  assert_true(app.has_prefix("create_window_ok"))
  let window = match app.window.val {
    Some(w) => w
    None => fail("window missing after surface init")
  }
  assert_eq(window.view_handle(), 0xA100UL)
  assert_eq(window.surface_size().width, 720)

  host_push(PointerMoved(10.0, 20.0))
  host_push(PointerButton(true, 10.0, 20.0))
  host_push(SurfaceResize(800, 1600, 3.0))
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("pointer_moved"))
  assert_true(app.has("pointer_button"))
  assert_eq(window.surface_size().width, 800)
  assert_eq(window.scale_factor(), 3.0)

  host_push(SurfaceTerm)
  host_push(Stop)
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("destroy_surfaces"))
  assert_true(app.has("suspended"))
  assert_eq(window.view_handle(), 0UL)

  host_push(Resume)
  host_push(SurfaceInit(0xA200UL, 0xB200UL, 720, 1280, 2.5))
  ignore(event_loop.pump_app_events(None, app))
  assert_eq(window.view_handle(), 0xA200UL)
  assert_eq(window.surface_token(), 0xB200UL)

  host_push(Destroy)
  match event_loop.pump_app_events(None, app) {
    Exit(_) => ()
    Continue => fail("expected exit after Destroy")
  }
  event_loop.drop()
}

///|
test "ios_host_sim_pointer_phase_scroll_ime" {
  host_reset_for_test()
  let event_loop = EventLoop::new()
  let app = HostSimApp::new()

  host_push(Start)
  host_push(Resume)
  host_push(SurfaceInit(0xA100UL, 0xB100UL, 720, 1280, 2.5))
  ignore(event_loop.pump_app_events(None, app))
  let window = match app.window.val {
    Some(w) => w
    None => fail("window missing")
  }
  let _ = window
  // Touch began+moved+ended via PointerPhase (phase 0/1/2).
  host_push(PointerPhase(0, 30.0, 40.0))
  host_push(PointerPhase(1, 32.0, 41.0))
  host_push(PointerPhase(2, 32.0, 41.0))
  // Pan scroll with translation (phase 1=Moved).
  host_push(Scroll(32.0, 41.0, 0.0, 25.0, 1))
  // IME commit text.
  host_push(ImeEvent(1, "hi", 0, 0))
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.has("pointer_moved"))
  assert_true(app.has("pointer_button"))
  assert_true(app.has_prefix("mouse_wheel"))
  assert_true(app.has_prefix("ime:"))
  event_loop.drop()
}
