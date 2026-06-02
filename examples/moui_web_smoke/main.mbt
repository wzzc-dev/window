///|
struct App {
  mut window : @web.Window?
  mut saw_redraw : Bool
  mut saw_resize : Bool
  mut saw_pointer : Bool
  mut saw_keyboard : Bool
  mut ready_printed : Bool
}

///|
fn App::maybe_ready(self : App) -> Unit {
  if !self.ready_printed &&
    self.saw_redraw &&
    self.saw_resize &&
    self.saw_pointer &&
    self.saw_keyboard {
    self.ready_printed = true
    println("MOUISmoke: ready")
  }
}

///|
fn log_surface(window : @web.Window) -> Unit {
  let size = window.surface_size()
  println(
    "MOUISmoke: surface canvas_id=\{window.canvas_id()} size=\{size.width()}x\{size.height()} scale=\{window.scale_factor()}",
  )
}

///|
pub impl @web.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  let surface_size : @dpi.PhysicalSize = PhysicalSize(640, 360)
  let attributes = @core.WindowAttributes::default()
    .with_title("MoUI window web smoke")
    .with_surface_size(surface_size.into_size())
  let web_attributes = @web.WindowAttributesWeb::default().with_canvas_id(
    "moui-web-smoke-canvas",
  )
  let window : @web.Window? = Some(
    event_loop.try_create_window_with_web_attributes(attributes, web_attributes),
  ) catch {
    err => {
      println("MOUISmoke: create failed \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      self.window = Some(window)
      log_surface(window)
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @web.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    CloseRequested => event_loop.exit()
    SurfaceResized(size) => {
      self.saw_resize = true
      match self.window {
        Some(window) => {
          println(
            "MOUISmoke: resize size=\{size.width()}x\{size.height()} scale=\{window.scale_factor()}",
          )
          window.request_redraw()
        }
        None => ()
      }
      self.maybe_ready()
    }
    RedrawRequested => {
      self.saw_redraw = true
      match self.window {
        Some(window) => {
          window.pre_present_notify()
          println("MOUISmoke: redraw pre_present_notify")
        }
        None => ()
      }
      self.maybe_ready()
    }
    PointerMoved(_, position, _, _) => {
      self.saw_pointer = true
      println("MOUISmoke: pointer x=\{position.x()} y=\{position.y()}")
      self.maybe_ready()
    }
    KeyboardInput(_, key_event, false) =>
      if key_event.state() is Pressed {
        self.saw_keyboard = true
        let text = match key_event.text() {
          Some(text) => text
          None => ""
        }
        println("MOUISmoke: keyboard text=\{text}")
        self.maybe_ready()
      }
    _ => ()
  }
}

///|
fn main {
  let event_loop = @web.EventLoop::new()
  event_loop.set_control_flow(Poll)
  event_loop.spawn_app({
    window: None,
    saw_redraw: false,
    saw_resize: false,
    saw_pointer: false,
    saw_keyboard: false,
    ready_printed: false,
  })
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
