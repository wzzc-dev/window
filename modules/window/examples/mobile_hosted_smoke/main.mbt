///|
/// MoUI cutover sketch: ApplicationHandler on window/android hosted backend.
struct MobileHostedSmokeApp {
  log : Ref[Array[String]]
  window : Ref[@android.Window?]
  presented : Ref[Bool]
}

///|
fn MobileHostedSmokeApp::new() -> MobileHostedSmokeApp {
  { log: Ref([]), window: Ref(None), presented: Ref(false) }
}

///|
fn MobileHostedSmokeApp::push(
  self : MobileHostedSmokeApp,
  msg : String,
) -> Unit {
  self.log.val.push(msg)
}

///|
pub impl @android.ApplicationHandler for MobileHostedSmokeApp with fn resumed(
  self,
  _event_loop,
) {
  self.push("resumed")
}

///|
pub impl @android.ApplicationHandler for MobileHostedSmokeApp with fn can_create_surfaces(
  self,
  event_loop,
) {
  self.push("can_create_surfaces")
  if self.window.val is None {
    let attrs = @core.WindowAttributes::default().with_title(
      "mobile-hosted-smoke",
    )
    let window = event_loop.create_window(attrs)
    self.window.val = Some(window)
    self.push("window_handle=\{window.native_window_handle()}")
  }
}

///|
pub impl @android.ApplicationHandler for MobileHostedSmokeApp with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.push("destroy_surfaces")
  match self.window.val {
    Some(window) =>
      self.push("invalidated_handle=\{window.native_window_handle()}")
    None => ()
  }
}

///|
pub impl @android.ApplicationHandler for MobileHostedSmokeApp with fn suspended(
  self,
  _event_loop,
) {
  self.push("suspended")
}

///|
pub impl @android.ApplicationHandler for MobileHostedSmokeApp with fn window_event(
  self,
  event_loop,
  _id,
  event,
) {
  match event {
    RedrawRequested =>
      match self.window.val {
        Some(window) => {
          window.pre_present_notify()
          let rc = window.clear_color(
            (32 : Int).to_byte(),
            (32 : Int).to_byte(),
            (48 : Int).to_byte(),
            (255 : Int).to_byte(),
          )
          self.push("present_rc=\{rc}")
          self.presented.val = rc == 0
        }
        None => ()
      }
    CloseRequested => event_loop.exit()
    _ => ()
  }
}

///|
test "mobile_hosted_smoke_application_handler_path" {
  @android.host_reset_for_test()
  let event_loop = @android.EventLoop::new()
  let app = MobileHostedSmokeApp::new()
  @android.host_push(@android.HostCmd::Start)
  @android.host_push(@android.HostCmd::Resume)
  @android.host_push(@android.HostCmd::SurfaceInit(0x55UL, 0UL, 320, 640, 2.0))
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.log.val.search_by(s => s == "resumed") is Some(_))
  assert_true(app.log.val.search_by(s => s == "can_create_surfaces") is Some(_))
  match app.window.val {
    Some(window) => {
      assert_eq(window.native_window_handle(), 0x55UL)
      window.request_redraw()
    }
    None => fail("window missing")
  }
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.presented.val)
  @android.host_push(@android.HostCmd::SurfaceTerm)
  @android.host_push(@android.HostCmd::Stop)
  ignore(event_loop.pump_app_events(None, app))
  assert_true(app.log.val.search_by(s => s == "destroy_surfaces") is Some(_))
  assert_true(app.log.val.search_by(s => s == "suspended") is Some(_))
  event_loop.drop()
}
