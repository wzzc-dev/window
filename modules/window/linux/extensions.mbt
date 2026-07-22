///|
pub struct WindowAttributesLinux {
  priv mut app_id_ : String?
  priv mut use_shm_placeholder_ : Bool
} derive(Eq, Debug)

///|
pub fn WindowAttributesLinux::default() -> WindowAttributesLinux {
  { app_id_: None, use_shm_placeholder_: true }
}

///|
pub fn WindowAttributesLinux::with_app_id(
  self : WindowAttributesLinux,
  app_id : String,
) -> WindowAttributesLinux {
  self.app_id_ = Some(app_id)
  self
}

///|
pub fn WindowAttributesLinux::app_id(self : WindowAttributesLinux) -> String? {
  self.app_id_
}

///|
pub fn WindowAttributesLinux::with_shm_placeholder(
  self : WindowAttributesLinux,
  enabled : Bool,
) -> WindowAttributesLinux {
  self.use_shm_placeholder_ = enabled
  self
}

///|
pub fn WindowAttributesLinux::use_shm_placeholder(
  self : WindowAttributesLinux,
) -> Bool {
  self.use_shm_placeholder_
}

///|
pub(open) trait EventLoopExtLinux {
  fn wl_display(Self) -> UInt64
  fn display_handle_wayland(Self) -> UInt64
}

///|
pub(open) trait ActiveEventLoopExtLinux {
  fn wl_display(Self) -> UInt64
  fn display_handle_wayland(Self) -> UInt64
}

///|
pub(open) trait WindowExtLinux {
  fn wl_display(Self) -> UInt64
  fn wl_surface(Self) -> UInt64
  fn xdg_surface(Self) -> UInt64
  fn xdg_toplevel(Self) -> UInt64
  fn uses_client_decorations(Self) -> Bool
}

///|
pub fn EventLoop::display_handle_wayland(self : EventLoop) -> UInt64 {
  self.wl_display()
}

///|
pub fn ActiveEventLoop::display_handle_wayland(
  self : ActiveEventLoop,
) -> UInt64 {
  self.wl_display()
}

///|
pub fn Window::wl_display(self : Window) -> UInt64 {
  native_window_display_handle(self.handle)
}

///|
pub fn Window::wl_surface(self : Window) -> UInt64 {
  native_window_surface_handle(self.handle)
}

///|
pub fn Window::xdg_surface(self : Window) -> UInt64 {
  native_window_xdg_surface_handle(self.handle)
}

///|
pub fn Window::xdg_toplevel(self : Window) -> UInt64 {
  native_window_xdg_toplevel_handle(self.handle)
}

///|
pub impl EventLoopExtLinux for EventLoop with fn wl_display(self) {
  self.wl_display()
}

///|
pub impl EventLoopExtLinux for EventLoop with fn display_handle_wayland(self) {
  self.display_handle_wayland()
}

///|
pub impl ActiveEventLoopExtLinux for ActiveEventLoop with fn wl_display(self) {
  self.wl_display()
}

///|
pub impl ActiveEventLoopExtLinux for ActiveEventLoop with fn display_handle_wayland(
  self,
) {
  self.display_handle_wayland()
}

///|
pub impl WindowExtLinux for Window with fn wl_display(self) {
  self.wl_display()
}

///|
pub impl WindowExtLinux for Window with fn wl_surface(self) {
  self.wl_surface()
}

///|
pub impl WindowExtLinux for Window with fn xdg_surface(self) {
  self.xdg_surface()
}

///|
pub impl WindowExtLinux for Window with fn xdg_toplevel(self) {
  self.xdg_toplevel()
}

///|
pub impl WindowExtLinux for Window with fn uses_client_decorations(self) {
  self.uses_client_decorations()
}
