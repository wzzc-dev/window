///|
/// The windowing system backing the Linux event loop. Selected at startup by
/// `native_backend.c` (MOUI_LINUX_WINDOWING / WAYLAND_DISPLAY / DISPLAY) and
/// stable for the lifetime of the process.
pub enum WindowingBackend {
  Wayland
  X11
} derive(Eq, Debug)

///|
fn windowing_backend_from_tag(tag : Int) -> WindowingBackend {
  // Tag 2 marks the X11 backend; anything else (including the invalid-handle
  // sentinel 0) resolves to the historical Wayland default.
  if tag == 2 {
    X11
  } else {
    Wayland
  }
}

///|
pub fn EventLoop::windowing_backend(self : EventLoop) -> WindowingBackend {
  windowing_backend_from_tag(native_backend_tag(self.context))
}

///|
pub fn ActiveEventLoop::windowing_backend(
  self : ActiveEventLoop,
) -> WindowingBackend {
  self.inner.windowing_backend()
}

///|
pub fn Window::windowing_backend(self : Window) -> WindowingBackend {
  windowing_backend_from_tag(native_backend_tag(self.handle))
}

///|
pub extend WindowingBackend with Debug::{to_repr}

///|
pub extend WindowingBackend with Eq::{not_equal, equal}
