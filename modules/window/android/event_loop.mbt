///|
pub struct EventLoopProxy {
  priv _unit : Unit
} derive(Eq, Debug)

///|
pub fn EventLoopProxy::wake_up(_self : EventLoopProxy) -> Unit {
  app_state_queue_proxy_wake_up()
}

///|
pub struct EventLoop {
  priv _unit : Unit
} derive(Eq, Debug)

///|
pub struct EventLoopBuilder {
  priv mut platform_attributes_ : @core.PlatformEventLoopAttributes
} derive(Eq, Debug)

///|
pub struct ActiveEventLoop {
  priv inner : EventLoop
} derive(Eq, Debug)

///|
pub fn EventLoop::builder() -> EventLoopBuilder {
  EventLoopBuilder::new()
}

///|
pub fn EventLoopBuilder::new() -> EventLoopBuilder {
  { platform_attributes_: @core.PlatformEventLoopAttributes::default() }
}

///|
pub fn EventLoopBuilder::EventLoopBuilder() -> EventLoopBuilder {
  EventLoopBuilder::new()
}

///|
pub fn EventLoopBuilder::default() -> EventLoopBuilder {
  EventLoopBuilder::new()
}

///|
pub fn EventLoopBuilder::with_platform_attributes(
  self : EventLoopBuilder,
  platform_attributes : @core.PlatformEventLoopAttributes,
) -> EventLoopBuilder {
  self.platform_attributes_ = platform_attributes
  self
}

///|
pub fn EventLoopBuilder::platform_attributes(
  self : EventLoopBuilder,
) -> @core.PlatformEventLoopAttributes {
  self.platform_attributes_
}

///|
pub fn EventLoopBuilder::with_activation_policy(
  self : EventLoopBuilder,
  _activation_policy : @core.ActivationPolicy,
) -> EventLoopBuilder {
  self
}

///|
pub fn EventLoopBuilder::with_default_menu(
  self : EventLoopBuilder,
  _default_menu : Bool,
) -> EventLoopBuilder {
  self
}

///|
pub fn EventLoopBuilder::with_activate_ignoring_other_apps(
  self : EventLoopBuilder,
  _ignore : Bool,
) -> EventLoopBuilder {
  self
}

///|
pub fn EventLoopBuilder::build(
  self : EventLoopBuilder,
) -> EventLoop raise @core.EventLoopError {
  EventLoop::try_new_with_platform_attributes(self.platform_attributes_)
}

///|
pub fn EventLoop::EventLoop() -> EventLoop {
  EventLoop::new()
}

///|
pub fn EventLoop::new() -> EventLoop {
  EventLoop::try_new() catch {
    _ => { _unit: () }
  }
}

///|
pub fn EventLoop::try_new() -> EventLoop raise @core.EventLoopError {
  EventLoop::try_new_with_platform_attributes(
    @core.PlatformEventLoopAttributes::default(),
  )
}

///|
pub fn EventLoop::new_with_platform_attributes(
  platform_attributes : @core.PlatformEventLoopAttributes,
) -> EventLoop {
  EventLoop::try_new_with_platform_attributes(platform_attributes) catch {
    _ => { _unit: () }
  }
}

///|
pub fn EventLoop::try_new_with_platform_attributes(
  _platform_attributes : @core.PlatformEventLoopAttributes,
) -> EventLoop raise @core.EventLoopError {
  if event_loop_global_created.val {
    raise @core.EventLoopError::RecreationAttempt
  }
  event_loop_global_created.val = true
  { _unit: () }
}

///|
pub fn EventLoop::drop(_self : EventLoop) -> Unit {
  event_loop_global_created.val = false
  app_state_set_running(false)
}

///|
pub fn EventLoop::create_proxy(_self : EventLoop) -> EventLoopProxy {
  { _unit: () }
}

///|
pub fn EventLoop::window_target(self : EventLoop) -> ActiveEventLoop {
  { inner: self }
}

///|
pub fn EventLoop::set_control_flow(
  _self : EventLoop,
  control_flow : @core.ControlFlow,
) -> Unit {
  app_state_set_control_flow(control_flow)
}

///|
pub fn EventLoop::control_flow(_self : EventLoop) -> @core.ControlFlow {
  app_state_control_flow()
}

///|
pub fn EventLoop::exit(_self : EventLoop) -> Unit {
  app_state_request_exit(0)
}

///|
pub fn EventLoop::exiting(_self : EventLoop) -> Bool {
  app_state_exit_requested()
}

///|
pub fn EventLoop::available_monitors(
  _self : EventLoop,
) -> Array[@core.MonitorHandle] {
  [default_monitor()]
}

///|
pub fn EventLoop::primary_monitor(_self : EventLoop) -> @core.MonitorHandle? {
  Some(default_monitor())
}

///|
pub fn EventLoop::system_theme(_self : EventLoop) -> @core.Theme? {
  None
}

///|
pub fn EventLoop::hide_application(_self : EventLoop) -> Unit {
  ()
}

///|
pub fn EventLoop::hide_other_applications(_self : EventLoop) -> Unit {
  ()
}

///|
pub fn EventLoop::set_allows_automatic_window_tabbing(
  _self : EventLoop,
  _enabled : Bool,
) -> Unit {
  ()
}

///|
pub fn EventLoop::allows_automatic_window_tabbing(_self : EventLoop) -> Bool {
  false
}

///|
pub fn EventLoop::listen_device_events(
  _self : EventLoop,
  _filter : @core.DeviceEvents,
) -> Unit {
  ()
}

///|
pub fn EventLoop::create_custom_cursor(
  _self : EventLoop,
  _source : @core.CustomCursorSource,
) -> @core.CustomCursor raise @core.RequestError {
  raise @core.RequestError::not_supported(
    "Android custom cursors are not supported",
  )
}

///|
pub fn EventLoop::display_handle(_self : EventLoop) -> UInt64 {
  0UL
}

///|
pub fn EventLoop::owned_display_handle(self : EventLoop) -> UInt64 {
  self.display_handle()
}

///|
pub fn EventLoop::rwh_06_handle(self : EventLoop) -> UInt64 {
  self.display_handle()
}

///|
pub fn EventLoop::create_window(
  self : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window {
  Window::new(self, attributes) catch {
    _ => abort("window create failed")
  }
}

///|
pub fn EventLoop::try_create_window(
  self : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  Window::new(self, attributes)
}

///|
fn[A : ApplicationHandler] dispatch_callback(
  handler : A,
  event_loop : EventLoop,
  callback : DeferredCallback,
) -> Unit {
  let active = event_loop.window_target()
  match callback {
    NewEvents(cause) => handler.new_events(active, cause)
    Resumed => handler.resumed(active)
    CanCreateSurfaces => handler.can_create_surfaces(active)
    ProxyWakeUp => handler.proxy_wake_up(active)
    WindowEvent(id, event) => handler.window_event(active, id, event)
    Suspended => handler.suspended(active)
    DestroySurfaces => handler.destroy_surfaces(active)
    MemoryWarning => handler.memory_warning(active)
  }
}

///|
fn[A : ApplicationHandler] pump_once(
  handler : A,
  event_loop : EventLoop,
) -> Unit {
  app_state_set_dispatch_callback(
    Some(callback => dispatch_callback(handler, event_loop, callback)),
  )
  app_state_dispatch_pending()
  let redraws = app_state_take_pending_redraws()
  for raw_id in redraws {
    handler.window_event(
      event_loop.window_target(),
      @core.WindowId::from_raw(raw_id),
      RedrawRequested,
    )
  }
  handler.about_to_wait(event_loop.window_target())
}

///|
pub fn[A : ApplicationHandler] EventLoop::pump_app_events(
  self : EventLoop,
  _timeout_ms : Int?,
  handler : A,
) -> @core.PumpStatus {
  if !app_state_is_running() {
    app_state_set_running(true)
    app_state_ensure_init_events()
  }
  host_drain_native_queue()
  ignore(host_drain_into_app_state())
  pump_once(handler, self)
  if app_state_exit_requested() {
    if host_surfaces_allowed() {
      // Destroy path may already have queued destroy_surfaces; ensure cleanup.
      ()
    }
    app_state_set_running(false)
    Exit(app_state_exit_code())
  } else {
    Continue
  }
}

///|
pub fn[A : ApplicationHandler] EventLoop::try_pump_app_events(
  self : EventLoop,
  timeout_ms : Int?,
  handler : A,
) -> @core.PumpStatus {
  self.pump_app_events(timeout_ms, handler)
}

///|
pub fn[A : ApplicationHandler] EventLoop::run_app_on_demand(
  self : EventLoop,
  handler : A,
) -> Unit {
  while true {
    match self.pump_app_events(None, handler) {
      Exit(_) => break
      Continue => sleep_ms(4)
    }
  }
}

///|
pub fn[A : ApplicationHandler] EventLoop::try_run_app_on_demand(
  self : EventLoop,
  handler : A,
) -> Unit {
  self.run_app_on_demand(handler)
}

///|
pub fn[A : ApplicationHandler] EventLoop::run_app(
  self : EventLoop,
  handler : A,
) -> Unit {
  self.run_app_on_demand(handler)
}

///|
pub fn[A : ApplicationHandler] EventLoop::try_run_app(
  self : EventLoop,
  handler : A,
) -> Unit {
  self.run_app(handler)
}

///|
pub fn ActiveEventLoop::create_window(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
) -> Window {
  self.inner.create_window(attributes)
}

///|
pub fn ActiveEventLoop::try_create_window(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  self.inner.try_create_window(attributes)
}

///|
pub fn ActiveEventLoop::create_window_with_android_attributes(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
  platform_attributes : WindowAttributesAndroid,
) -> Window {
  Window::new_with_android_attributes(
    self.inner,
    attributes,
    platform_attributes,
  ) catch {
    _ => abort("window create failed")
  }
}

///|
pub fn ActiveEventLoop::try_create_window_with_android_attributes(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
  platform_attributes : WindowAttributesAndroid,
) -> Window raise @core.RequestError {
  Window::new_with_android_attributes(
    self.inner,
    attributes,
    platform_attributes,
  )
}

///|
pub fn ActiveEventLoop::create_custom_cursor(
  self : ActiveEventLoop,
  source : @core.CustomCursorSource,
) -> @core.CustomCursor raise @core.RequestError {
  self.inner.create_custom_cursor(source)
}

///|
pub fn ActiveEventLoop::available_monitors(
  self : ActiveEventLoop,
) -> Array[@core.MonitorHandle] {
  self.inner.available_monitors()
}

///|
pub fn ActiveEventLoop::primary_monitor(
  self : ActiveEventLoop,
) -> @core.MonitorHandle? {
  self.inner.primary_monitor()
}

///|
pub fn ActiveEventLoop::create_proxy(self : ActiveEventLoop) -> EventLoopProxy {
  self.inner.create_proxy()
}

///|
pub fn ActiveEventLoop::listen_device_events(
  self : ActiveEventLoop,
  filter : @core.DeviceEvents,
) -> Unit {
  self.inner.listen_device_events(filter)
}

///|
pub fn ActiveEventLoop::system_theme(self : ActiveEventLoop) -> @core.Theme? {
  self.inner.system_theme()
}

///|
pub fn ActiveEventLoop::hide_application(self : ActiveEventLoop) -> Unit {
  self.inner.hide_application()
}

///|
pub fn ActiveEventLoop::hide_other_applications(self : ActiveEventLoop) -> Unit {
  self.inner.hide_other_applications()
}

///|
pub fn ActiveEventLoop::set_allows_automatic_window_tabbing(
  self : ActiveEventLoop,
  enabled : Bool,
) -> Unit {
  self.inner.set_allows_automatic_window_tabbing(enabled)
}

///|
pub fn ActiveEventLoop::allows_automatic_window_tabbing(
  self : ActiveEventLoop,
) -> Bool {
  self.inner.allows_automatic_window_tabbing()
}

///|
pub fn ActiveEventLoop::set_control_flow(
  self : ActiveEventLoop,
  control_flow : @core.ControlFlow,
) -> Unit {
  self.inner.set_control_flow(control_flow)
}

///|
pub fn ActiveEventLoop::control_flow(
  self : ActiveEventLoop,
) -> @core.ControlFlow {
  self.inner.control_flow()
}

///|
pub fn ActiveEventLoop::exit(self : ActiveEventLoop) -> Unit {
  self.inner.exit()
}

///|
pub fn ActiveEventLoop::exiting(self : ActiveEventLoop) -> Bool {
  self.inner.exiting()
}

///|
pub fn ActiveEventLoop::rwh_06_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.rwh_06_handle()
}

///|
pub fn ActiveEventLoop::owned_display_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.owned_display_handle()
}

///|
pub fn ActiveEventLoop::display_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.display_handle()
}
