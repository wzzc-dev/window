///|
test "ios_request_ime_update_state_machine" {
  host_reset_for_test()
  host_push(Start)
  host_push(Resume)
  host_push(SurfaceInit(1UL, 2UL, 100, 200, 2.0))
  let event_loop = EventLoop::new()
  let app = HostSimApp::new()
  ignore(event_loop.pump_app_events(None, app))
  let window = match app.window.val {
    Some(w) => w
    None => fail("window required")
  }
  let data = @core.ImeRequestData::default().with_hint_and_purpose(
    @core.ImeHint::completion(),
    Normal,
  )
  let enable = @core.ImeEnableRequest::from_capabilities(
    @core.ImeCapabilities::default().with_hint_and_purpose(),
    data,
  )
  guard enable is Some(enable) else { fail("expected enable request") }
  window.request_ime_update(Enable(enable)) catch {
    err => fail("expected enable, got \{err}")
  }
  assert_true(window.ime_allowed())
  window.request_ime_update(Disable) catch {
    err => fail("expected disable, got \{err}")
  }
  assert_true(!window.ime_allowed())
  event_loop.drop()
}
