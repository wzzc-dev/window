///|
struct App {
  mut window : @linux.Window?
}

///|
pub impl @linux.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  let attrs = @core.WindowAttributes::default()
    .with_title("MoonBit window linux")
    .with_surface_size(@dpi.PhysicalSize::PhysicalSize(640, 360).into_size())
  let linux_attrs = @linux.WindowAttributesLinux::default().with_app_id(
    "Milky2018.window.example",
  )
  let window = event_loop.create_window_with_linux_attributes(
    attrs, linux_attrs,
  )
  self.window = Some(window)
  window.request_redraw()
}

///|
pub impl @linux.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  println("\{event}")
  match event {
    @core.WindowEvent::CloseRequested => event_loop.exit()
    @core.WindowEvent::SurfaceResized(_) =>
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
    @core.WindowEvent::RedrawRequested =>
      match self.window {
        Some(window) => window.pre_present_notify()
        None => ()
      }
    _ => ()
  }
}

///|
fn main {
  let event_loop = @linux.EventLoop::new()
  event_loop.set_control_flow(@core.ControlFlow::Wait)
  event_loop.run_app({ window: None })
}
