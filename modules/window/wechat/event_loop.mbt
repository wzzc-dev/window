///|
/// WeChat Mini Program event loop.
///
/// WeChat Mini Programs do not own the system event loop. The Mini Program
/// runtime calls lifecycle methods explicitly:
/// - `handle_resumed` / `handle_suspended` on app show/hide
/// - `handle_can_create_surfaces` / `handle_destroy_surfaces` on canvas lifecycle
/// - `handle_event` for touch/pointer events
///
/// The `run_app` / `spawn_app` entrypoints dispatch a fixed sequence of
/// synthetic lifecycle events and return immediately. The host JS runtime
/// calls back into MoonBit via exported functions (`wechat_dispatch_event`,
/// `wechat_render_frame`, etc.) for subsequent events.

///|
pub(all) struct EventLoop {
  priv _unit : Unit
}

///|
pub fn EventLoop::new() -> EventLoop {
  { _unit: () }
}

///|
pub fn EventLoop::as_active(self : EventLoop) -> ActiveEventLoop {
  { inner: self }
}

///|
pub fn EventLoop::window_target(self : EventLoop) -> ActiveEventLoop {
  self.as_active()
}

///|
pub fn[A : ApplicationHandler] EventLoop::run_app(
  self : EventLoop,
  handler : A,
) -> Unit {
  // Dispatch initial lifecycle events synchronously
  let active = self.as_active()
  handler.new_events(active, @core.StartCause::Init)
  handler.resumed(active)
  handler.can_create_surfaces(active)
  handler.new_events(active, @core.StartCause::Poll)
  handler.window_event(
    active,
    @core.WindowId::from_raw(0),
    @core.WindowEvent::RedrawRequested,
  )
}

///|
pub fn[A : ApplicationHandler] EventLoop::spawn_app(
  self : EventLoop,
  handler : A,
) -> Unit {
  self.run_app(handler)
}

///|
pub fn[A : ApplicationHandler] EventLoop::handle_event(
  self : EventLoop,
  handler : A,
  event : @core.WindowEvent,
) -> Unit {
  handler.window_event(self.as_active(), @core.WindowId::from_raw(0), event)
}

///|
pub fn[A : ApplicationHandler] EventLoop::handle_resumed(
  self : EventLoop,
  handler : A,
) -> Unit {
  handler.new_events(self.as_active(), @core.StartCause::Init)
  handler.resumed(self.as_active())
}

///|
pub fn[A : ApplicationHandler] EventLoop::handle_suspended(
  self : EventLoop,
  handler : A,
) -> Unit {
  handler.suspended(self.as_active())
}

///|
pub fn[A : ApplicationHandler] EventLoop::handle_destroy_surfaces(
  self : EventLoop,
  handler : A,
) -> Unit {
  handler.destroy_surfaces(self.as_active())
}

///|
pub fn[A : ApplicationHandler] EventLoop::handle_can_create_surfaces(
  self : EventLoop,
  handler : A,
) -> Unit {
  handler.can_create_surfaces(self.as_active())
}

// --- EventLoop Control ---

///|
pub fn EventLoop::set_control_flow(
  _self : EventLoop,
  _control_flow : @core.ControlFlow,
) -> Unit {
  ()
}

///|
pub fn EventLoop::control_flow(self : EventLoop) -> @core.ControlFlow {
  let _ = self
  @core.ControlFlow::Poll
}

///|
pub fn EventLoop::exit(_self : EventLoop) -> Unit {
  ()
}

///|
pub fn EventLoop::exiting(self : EventLoop) -> Bool {
  let _ = self
  false
}

///|
pub fn EventLoop::create_proxy(self : EventLoop) -> EventLoopProxy {
  let _ = self
  { _unit: () }
}

// --- Monitor ---

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
fn default_monitor() -> @core.MonitorHandle {
  @core.MonitorHandle::MonitorHandle(
    (0 : Int).to_uint64(),
    Some("WeChat viewport"),
    @dpi.PhysicalPosition::PhysicalPosition(0, 0),
    @dpi.PhysicalSize::PhysicalSize(0, 0),
    1.0,
    None,
    [],
  )
}

// --- System Theme ---

///|
pub fn EventLoop::system_theme(_self : EventLoop) -> @core.Theme? {
  None
}

// --- Window Creation ---

///|
pub fn EventLoop::create_window(
  _self : EventLoop,
  window_attributes : @core.WindowAttributes,
) -> Window {
  let size = match window_attributes.inner_size() {
    Some(s) => s
    None => @dpi.Size::from_logical(@dpi.LogicalSize::LogicalSize(375.0, 812.0))
  }
  Window::new(
    id=@core.WindowId::from_raw(0),
    canvas_id=window_attributes.name().unwrap_or("moui-canvas"),
    size~,
  )
}

// --- Desktop-only APIs (NoOp / NotSupported) ---

///|
pub fn EventLoop::hide_application(self : EventLoop) -> Unit {
  let _ = self
}

///|
pub fn EventLoop::hide_other_applications(self : EventLoop) -> Unit {
  let _ = self
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
    "WeChat Mini Program custom cursors are not supported",
  )
}

///|
pub fn EventLoop::display_handle(self : EventLoop) -> UInt64 {
  let _ = self
  (0 : Int).to_uint64()
}

///|
pub fn EventLoop::owned_display_handle(self : EventLoop) -> UInt64 {
  self.display_handle()
}

///|
pub fn EventLoop::rwh_06_handle(self : EventLoop) -> UInt64 {
  self.display_handle()
}

// --- EventLoopProxy ---

///|
pub(all) struct EventLoopProxy {
  priv _unit : Unit
}

///|
pub fn EventLoopProxy::wake_up(_self : EventLoopProxy) -> Unit {
  ()
}

///|
pub(all) struct ActiveEventLoop {
  priv inner : EventLoop
}

// --- ActiveEventLoop delegation ---

///|
pub fn ActiveEventLoop::create_window(
  self : ActiveEventLoop,
  window_attributes : @core.WindowAttributes,
) -> Window {
  self.inner.create_window(window_attributes)
}

///|
pub fn ActiveEventLoop::request_redraw(
  _self : ActiveEventLoop,
  _window : Window,
) -> Unit {
  // Redraw is handled by the JS runtime via wechat_render_frame()
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
pub fn ActiveEventLoop::create_custom_cursor(
  self : ActiveEventLoop,
  source : @core.CustomCursorSource,
) -> @core.CustomCursor raise @core.RequestError {
  self.inner.create_custom_cursor(source)
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
pub fn ActiveEventLoop::display_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.display_handle()
}

///|
pub fn ActiveEventLoop::owned_display_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.owned_display_handle()
}

///|
pub fn ActiveEventLoop::rwh_06_handle(self : ActiveEventLoop) -> UInt64 {
  self.inner.rwh_06_handle()
}
