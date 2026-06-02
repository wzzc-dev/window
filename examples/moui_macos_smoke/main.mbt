///|
struct App {
  mut window : @macos.Window?
  mut saw_handle : Bool
  mut saw_redraw : Bool
  mut saw_resize : Bool
  mut saw_pointer : Bool
  mut saw_keyboard : Bool
  mut requested_resize : Bool
  mut requested_input : Bool
  mut ready_printed : Bool
  mut wait_count : Int
}

///|
extern "C" fn native_send_input(raw_view_handle : UInt64) -> Int = "mbw_moui_macos_smoke_send_input"

///|
fn App::maybe_ready(self : App, event_loop : @macos.ActiveEventLoop) -> Unit {
  if !self.ready_printed &&
    self.saw_handle &&
    self.saw_redraw &&
    self.saw_resize &&
    self.saw_pointer &&
    self.saw_keyboard {
    self.ready_printed = true
    println("MOUIMacSmoke: ready")
    event_loop.exit()
  }
}

///|
fn log_surface(window : @macos.Window) -> Unit {
  let size = window.surface_size()
  println(
    "MOUIMacSmoke: surface size=\{size.width()}x\{size.height()} scale=\{window.scale_factor()}",
  )
}

///|
fn log_handles(window : @macos.Window) -> Bool {
  let window_handle = window.window_handle()
  let content_view_handle = window.content_view_handle() catch {
    err => {
      println("MOUIMacSmoke: content_view_handle failed \{err}")
      (0 : Int).to_uint64()
    }
  }
  println(
    "MOUIMacSmoke: handles window=0x\{window_handle.to_string(radix=16)} content_view=0x\{content_view_handle.to_string(radix=16)}",
  )
  window_handle != (0 : Int).to_uint64() &&
  content_view_handle != (0 : Int).to_uint64()
}

///|
fn log_monitor_probe(window : @macos.Window) -> Unit {
  let monitors = window.available_monitors()
  let primary = window.primary_monitor()
  let current = window.current_monitor()
  println(
    "MOUIMacSmoke: monitors count=\{monitors.length()} primary=\{primary is Some(_)} current=\{current is Some(_)}",
  )
}

///|
fn log_cursor_probe(window : @macos.Window) -> Unit {
  window.set_cursor_icon(Text)
  println("MOUIMacSmoke: cursor \{window.cursor()}")
}

///|
pub impl @macos.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  event_loop.set_control_flow(Poll)
  let initial_size : @dpi.PhysicalSize = PhysicalSize(320, 180)
  let attributes = @core.WindowAttributes::default()
    .with_title("MoUI macOS smoke")
    .with_surface_size(initial_size.into_size())
  let window : @macos.Window? = Some(event_loop.try_create_window(attributes)) catch {
    err => {
      println("MOUIMacSmoke: create failed \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      self.window = Some(window)
      log_surface(window)
      self.saw_handle = log_handles(window)
      log_monitor_probe(window)
      log_cursor_probe(window)
      let resized_size : @dpi.PhysicalSize = PhysicalSize(400, 240)
      ignore(window.request_surface_size(resized_size.into_size()))
      self.requested_resize = true
      println(
        "MOUIMacSmoke: resize requested size=\{resized_size.width()}x\{resized_size.height()}",
      )
      let input_handle = window.content_view_handle() catch {
        err => {
          println("MOUIMacSmoke: input handle failed \{err}")
          (0 : Int).to_uint64()
        }
      }
      if input_handle != (0 : Int).to_uint64() &&
        native_send_input(input_handle) != 0 {
        self.requested_input = true
        println("MOUIMacSmoke: input requested")
      } else {
        println("MOUIMacSmoke: input request failed")
      }
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @macos.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    SurfaceResized(size) => {
      self.saw_resize = true
      println("MOUIMacSmoke: resize size=\{size.width()}x\{size.height()}")
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
      self.maybe_ready(event_loop)
    }
    PointerMoved(_, position, _, _) => {
      self.saw_pointer = true
      println("MOUIMacSmoke: pointer x=\{position.x()} y=\{position.y()}")
      self.maybe_ready(event_loop)
    }
    KeyboardInput(_, key_event, false) =>
      if key_event.state() is Pressed {
        self.saw_keyboard = true
        let text = match key_event.text() {
          Some(text) => text
          None => ""
        }
        println("MOUIMacSmoke: keyboard text=\{text}")
        self.maybe_ready(event_loop)
      }
    RedrawRequested => {
      self.saw_redraw = true
      match self.window {
        Some(window) => {
          window.pre_present_notify()
          @util.fill_window(window)
          println("MOUIMacSmoke: redraw pre_present_notify")
        }
        None => ()
      }
      self.maybe_ready(event_loop)
    }
    Destroyed => println("MOUIMacSmoke: destroyed")
    CloseRequested => event_loop.exit()
    _ => ()
  }
}

///|
pub impl @macos.ApplicationHandler for App with fn about_to_wait(
  self,
  event_loop,
) {
  self.wait_count += 1
  match self.window {
    Some(window) => if !self.saw_redraw { window.request_redraw() }
    None => ()
  }
  self.maybe_ready(event_loop)
  if self.wait_count > 240 && !self.ready_printed {
    println(
      "MOUIMacSmoke: failed handles=\{self.saw_handle} redraw=\{self.saw_redraw} resize=\{self.saw_resize} pointer=\{self.saw_pointer} keyboard=\{self.saw_keyboard} requested_resize=\{self.requested_resize} requested_input=\{self.requested_input}",
    )
    event_loop.exit()
  }
}

///|
fn main {
  @util.tracing_init()
  let event_loop = @macos.EventLoop::EventLoop()
  event_loop.run_app({
    window: None,
    saw_handle: false,
    saw_redraw: false,
    saw_resize: false,
    saw_pointer: false,
    saw_keyboard: false,
    requested_resize: false,
    requested_input: false,
    ready_printed: false,
    wait_count: 0,
  })
  println("MOUIMacSmoke: finished")
}
