///|
struct App {
  mut window : @web.Window?
}

///|
pub impl @web.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  let surface_size : @dpi.PhysicalSize = PhysicalSize(640, 360)
  let attributes = @core.WindowAttributes::default()
    .with_title("MoonBit window web")
    .with_surface_size(surface_size.into_size())
  let window = event_loop.create_window(attributes)
  self.window = Some(window)
  window.request_redraw()
}

///|
pub impl @web.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  println("\{event}")
  match event {
    CloseRequested => event_loop.exit()
    SurfaceResized(_) =>
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
    RedrawRequested =>
      match self.window {
        Some(window) => window.pre_present_notify()
        None => ()
      }
    _ => ()
  }
}

///|
fn main {
  let event_loop = @web.EventLoop::new()
  event_loop.set_control_flow(Poll)
  event_loop.spawn_app({ window: None })
}

///|
pub fn web_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  @web.web_dispatch_event_by_id(kind, raw_id, arg0, arg1, argd, text_id)
}
