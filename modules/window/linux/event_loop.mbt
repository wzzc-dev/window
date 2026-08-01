///|
pub struct EventLoopProxy {
  priv context : UInt64
  priv wake_fd : Int
} derive(Eq, Debug)

///|
pub fn EventLoopProxy::wake_up(self : EventLoopProxy) -> Unit {
  let _ = self.wake_fd
  native_context_wake(self.context)
}

///|
pub struct EventLoop {
  priv context : UInt64
  priv wake_fd : Int
} derive(Debug)

///|
pub struct EventLoopBuilder {
  priv mut platform_attributes_ : @core.PlatformEventLoopAttributes
} derive(Eq, Debug)

///|
pub struct ActiveEventLoop {
  priv inner : EventLoop
} derive(Debug)

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
  _activate : Bool,
) -> EventLoopBuilder {
  self
}

///|
pub fn EventLoopBuilder::with_any_thread(
  self : EventLoopBuilder,
  _any_thread : Bool,
) -> EventLoopBuilder {
  self
}

///|
pub fn EventLoopBuilder::build(self : EventLoopBuilder) -> EventLoop {
  try! self.try_build()
}

///|
pub fn EventLoopBuilder::try_build(
  self : EventLoopBuilder,
) -> EventLoop raise @core.EventLoopError {
  EventLoop::try_new_with_platform_attributes(self.platform_attributes_)
}

///|
pub fn EventLoop::new() -> EventLoop {
  try! EventLoop::try_new()
}

///|
pub fn EventLoop::EventLoop() -> EventLoop {
  EventLoop::new()
}

///|
pub fn EventLoop::try_new() -> EventLoop raise @core.EventLoopError {
  EventLoop::builder().try_build()
}

///|
pub fn EventLoop::new_with_platform_attributes(
  attributes : @core.PlatformEventLoopAttributes,
) -> EventLoop {
  try! EventLoop::try_new_with_platform_attributes(attributes)
}

///|
pub fn EventLoop::try_new_with_platform_attributes(
  _attributes : @core.PlatformEventLoopAttributes,
) -> EventLoop raise @core.EventLoopError {
  if event_loop_global_created.val {
    raise @core.EventLoopError::RecreationAttempt
  }
  let context = native_context_new()
  if context == (0 : Int).to_uint64() {
    raise @core.EventLoopError::os("OS error")
  }
  let wake_fd = native_context_wake_fd(context)
  app_state_set_context(context)
  app_state_install_native_callbacks()
  event_loop_global_created.val = true
  { context, wake_fd }
}

///|
fn EventLoop::as_active(self : EventLoop) -> ActiveEventLoop {
  { inner: self }
}

///|
pub fn EventLoop::window_target(self : EventLoop) -> ActiveEventLoop {
  self.as_active()
}

///|
pub fn EventLoop::drop(self : EventLoop) -> Unit {
  native_context_destroy(self.context)
}

///|
pub fn EventLoop::create_window(
  self : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window {
  try! self.try_create_window(attributes)
}

///|
pub fn EventLoop::try_create_window(
  self : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  Window::new(self, attributes)
}

///|
pub fn EventLoop::create_window_with_linux_attributes(
  self : EventLoop,
  attributes : @core.WindowAttributes,
  linux_attributes : WindowAttributesLinux,
) -> Window {
  try! self.try_create_window_with_linux_attributes(
    attributes, linux_attributes,
  )
}

///|
pub fn EventLoop::try_create_window_with_linux_attributes(
  self : EventLoop,
  attributes : @core.WindowAttributes,
  linux_attributes : WindowAttributesLinux,
) -> Window raise @core.RequestError {
  Window::new_with_linux_attributes(self, attributes, linux_attributes)
}

///|
pub fn EventLoop::create_proxy(self : EventLoop) -> EventLoopProxy {
  { context: self.context, wake_fd: self.wake_fd }
}

///|
pub fn EventLoop::set_control_flow(
  _self : EventLoop,
  control_flow : @core.ControlFlow,
) -> Unit {
  app_state_set_control_flow(control_flow)
}

///|
pub fn EventLoop::control_flow(self : EventLoop) -> @core.ControlFlow {
  let _ = self
  app_state_control_flow()
}

///|
pub fn EventLoop::exit(_self : EventLoop) -> Unit {
  app_state_set_exit(0)
}

///|
pub fn EventLoop::exiting(self : EventLoop) -> Bool {
  let _ = self
  app_state_exit_requested()
}

///|
pub fn EventLoop::available_monitors(
  _self : EventLoop,
) -> Array[@core.MonitorHandle] {
  available_monitors()
}

///|
pub fn EventLoop::primary_monitor(_self : EventLoop) -> @core.MonitorHandle? {
  primary_monitor()
}

///|
pub fn EventLoop::system_theme(self : EventLoop) -> @core.Theme? {
  theme_from_native(native_context_system_theme(self.context))
}

///|
pub fn EventLoop::hide_application(self : EventLoop) -> Unit {
  self.as_active().hide_application()
}

///|
pub fn EventLoop::hide_other_applications(self : EventLoop) -> Unit {
  self.as_active().hide_other_applications()
}

///|
pub fn EventLoop::set_allows_automatic_window_tabbing(
  self : EventLoop,
  _enabled : Bool,
) -> Unit {
  let _ = self
}

///|
pub fn EventLoop::allows_automatic_window_tabbing(self : EventLoop) -> Bool {
  let _ = self
  false
}

///|
pub fn EventLoop::listen_device_events(
  _self : EventLoop,
  _allowed : @core.DeviceEvents,
) -> Unit {
  ()
}

///|
pub fn EventLoop::create_custom_cursor(
  self : EventLoop,
  _source : @core.CustomCursorSource,
) -> @core.CustomCursor raise @core.RequestError {
  let _ = self
  raise @core.RequestError::not_supported(
    "Linux custom cursors are not supported yet",
  )
}

///|
pub fn EventLoop::native_display_handle(self : EventLoop) -> UInt64 {
  native_context_display_handle(self.context)
}

///|
pub fn EventLoop::owned_display_handle(self : EventLoop) -> UInt64 {
  self.native_display_handle()
}

///|
pub fn EventLoop::rwh_06_handle(self : EventLoop) -> UInt64 {
  self.native_display_handle()
}

///|
pub fn EventLoop::wl_display(self : EventLoop) -> UInt64 {
  native_context_display_handle(self.context)
}

///|
pub fn EventLoop::raw_display_handle(
  self : EventLoop,
) -> @windowing.RawDisplayHandle raise @windowing.HandleError {
  Wayland(@windowing.WaylandDisplayHandle::new(self.native_display_handle()))
}

///|
pub impl @windowing.DisplayHandleProvider for EventLoop with fn raw_display_handle(
  self,
) {
  self.raw_display_handle()
}

///|
pub fn EventLoop::display_handle(self : EventLoop) -> @windowing.DisplayHandle {
  @windowing.DisplayHandle::from_provider(
    self as &@windowing.DisplayHandleProvider,
  )
}

///|
pub impl @windowing.HasDisplayHandle for EventLoop with fn display_handle(self) {
  self.display_handle()
}

///|
pub fn ActiveEventLoop::create_window(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
) -> Window {
  try! self.try_create_window(attributes)
}

///|
pub fn ActiveEventLoop::try_create_window(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  self.inner.try_create_window(attributes)
}

///|
pub fn ActiveEventLoop::create_window_with_linux_attributes(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
  linux_attributes : WindowAttributesLinux,
) -> Window {
  try! self.try_create_window_with_linux_attributes(
    attributes, linux_attributes,
  )
}

///|
pub fn ActiveEventLoop::try_create_window_with_linux_attributes(
  self : ActiveEventLoop,
  attributes : @core.WindowAttributes,
  linux_attributes : WindowAttributesLinux,
) -> Window raise @core.RequestError {
  self.inner.try_create_window_with_linux_attributes(
    attributes, linux_attributes,
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
  allowed : @core.DeviceEvents,
) -> Unit {
  self.inner.listen_device_events(allowed)
}

///|
pub fn ActiveEventLoop::system_theme(self : ActiveEventLoop) -> @core.Theme? {
  self.inner.system_theme()
}

///|
pub fn ActiveEventLoop::hide_application(self : ActiveEventLoop) -> Unit {
  let _ = self
}

///|
pub fn ActiveEventLoop::hide_other_applications(self : ActiveEventLoop) -> Unit {
  let _ = self
}

///|
pub fn ActiveEventLoop::set_allows_automatic_window_tabbing(
  self : ActiveEventLoop,
  _enabled : Bool,
) -> Unit {
  let _ = self
}

///|
pub fn ActiveEventLoop::allows_automatic_window_tabbing(
  self : ActiveEventLoop,
) -> Bool {
  let _ = self
  false
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
pub fn ActiveEventLoop::native_display_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.native_display_handle()
}

///|
pub fn ActiveEventLoop::owned_display_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.owned_display_handle()
}

///|
pub fn ActiveEventLoop::wl_display(self : ActiveEventLoop) -> UInt64 {
  self.inner.wl_display()
}

///|
pub fn ActiveEventLoop::raw_display_handle(
  self : ActiveEventLoop,
) -> @windowing.RawDisplayHandle raise @windowing.HandleError {
  self.inner.raw_display_handle()
}

///|
pub impl @windowing.DisplayHandleProvider for ActiveEventLoop with fn raw_display_handle(
  self,
) {
  self.raw_display_handle()
}

///|
pub fn ActiveEventLoop::display_handle(
  self : ActiveEventLoop,
) -> @windowing.DisplayHandle {
  @windowing.DisplayHandle::from_provider(
    self as &@windowing.DisplayHandleProvider,
  )
}

///|
pub impl @windowing.HasDisplayHandle for ActiveEventLoop with fn display_handle(
  self,
) {
  self.display_handle()
}

///|
fn[A : ApplicationHandler] EventLoop::dispatch_events(
  self : EventLoop,
  app : A,
) -> Unit {
  app_state_dispatch_redraws(app, self.as_active())
  app_state_dispatch_deferred_callbacks(app, self.as_active())
}

///|
fn control_flow_timeout_ms(
  control_flow : @core.ControlFlow,
  blocking : Bool,
) -> Int {
  match control_flow {
    @core.ControlFlow::Poll => 0
    @core.ControlFlow::Wait => if blocking { -1 } else { 0 }
    @core.ControlFlow::WaitUntil(ms) => {
      let now = native_now_ms()
      let timeout = if ms <= now { 0 } else { (ms - now).to_int() }
      if blocking {
        timeout
      } else {
        0
      }
    }
  }
}

///|
fn[A : ApplicationHandler] EventLoop::run_message_loop(
  self : EventLoop,
  app : A,
  blocking : Bool,
) -> Unit {
  let mut continue_loop = true
  while continue_loop {
    let timeout_ms = control_flow_timeout_ms(app_state_control_flow(), blocking)
    let dispatched = native_context_dispatch(self.context, timeout_ms)
    self.dispatch_events(app)
    app_state_queue_callback(AboutToWait)
    app_state_dispatch_deferred_callbacks(app, self.as_active())
    if app_state_exit_requested() {
      continue_loop = false
    } else if !blocking {
      continue_loop = false
    } else if dispatched < 0 {
      app_state_set_exit(1)
      continue_loop = false
    }
  }
}

///|
pub fn[A : ApplicationHandler] EventLoop::run_app(
  self : EventLoop,
  app : A,
) -> Unit {
  try! self.try_run_app(app)
}

///|
pub fn[A : ApplicationHandler] EventLoop::try_run_app(
  self : EventLoop,
  app : A,
) -> Unit raise @core.EventLoopError {
  if app_state_is_running() {
    raise @core.EventLoopError::RecreationAttempt
  }
  app_state_set_running(true)
  app_state_clear_exit()
  app_state_set_dispatch_handler(app, self.as_active())
  app_state_dispatch_init_events(app, self.as_active())
  self.run_message_loop(app, true)
  app_state_internal_exit()
  app_state_clear_dispatch_handler()
}

///|
pub fn[A : ApplicationHandler] EventLoop::run_app_on_demand(
  self : EventLoop,
  app : A,
) -> Unit {
  try! self.try_run_app_on_demand(app)
}

///|
pub fn[A : ApplicationHandler] EventLoop::try_run_app_on_demand(
  self : EventLoop,
  app : A,
) -> Unit raise @core.EventLoopError {
  self.try_run_app(app)
}

///|
pub fn[A : ApplicationHandler] EventLoop::pump_app_events(
  self : EventLoop,
  timeout_ms : Int?,
  app : A,
) -> @core.PumpStatus {
  self.try_pump_app_events(timeout_ms, app)
}

///|
pub fn[A : ApplicationHandler] EventLoop::try_pump_app_events(
  self : EventLoop,
  timeout_ms : Int?,
  app : A,
) -> @core.PumpStatus {
  if !app_state_is_running() {
    app_state_set_running(true)
    app_state_clear_exit()
    app_state_set_dispatch_handler(app, self.as_active())
    app_state_dispatch_init_events(app, self.as_active())
  } else {
    app_state_set_dispatch_handler(app, self.as_active())
  }
  match timeout_ms {
    Some(ms) => ignore(native_context_dispatch(self.context, ms))
    None => self.run_message_loop(app, false)
  }
  self.dispatch_events(app)
  if app_state_exit_requested() {
    @core.PumpStatus::Exit(app_state_exit_code())
  } else {
    @core.PumpStatus::Continue
  }
}
