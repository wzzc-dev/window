///|
/// WeChat Mini Program event loop.
/// Similar to the web event loop, dispatches events through a callback.

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
  handler.window_event(active, @core.WindowId::from_raw(0), @core.WindowEvent::RedrawRequested)
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
  handler.window_event(
    self.as_active(),
    @core.WindowId::from_raw(0),
    event,
  )
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

///|
pub(all) struct ActiveEventLoop {
  priv inner : EventLoop
}

///|
pub fn ActiveEventLoop::create_window(
  self : ActiveEventLoop,
  window_attributes : @core.WindowAttributes,
) -> Window {
  let size = match window_attributes.inner_size() {
    Some(s) => s
    None => @dpi.Size::from_logical(@dpi.LogicalSize::LogicalSize(375.0, 812.0))
  }
  Window::new(
    id=@core.WindowId::from_raw(0),
    canvas_id=window_attributes.name().or("moui-canvas"),
    size~,
  )
}

///|
pub fn ActiveEventLoop::request_redraw(
  self : ActiveEventLoop,
  _window : Window,
) -> Unit {
  // Redraw is handled by the JS runtime
}