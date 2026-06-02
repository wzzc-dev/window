///|
struct App {
  mut window : @windows.Window?
  mut saw_handle : Bool
  mut saw_redraw : Bool
  mut saw_resize : Bool
  mut saw_pointer : Bool
  mut saw_keyboard : Bool
  mut saw_text : Bool
  mut requested_resize : Bool
  mut requested_input : Bool
  mut ready_printed : Bool
  mut wait_count : Int
}

///|
extern "C" fn native_send_input(raw_hwnd : UInt64) -> Int = "mbw_moui_windows_smoke_send_input"

///|
fn App::maybe_ready(self : App, event_loop : @windows.ActiveEventLoop) -> Unit {
  if !self.ready_printed &&
    self.saw_handle &&
    self.saw_redraw &&
    self.saw_resize &&
    self.saw_pointer &&
    self.saw_keyboard &&
    self.saw_text {
    self.ready_printed = true
    println("MOUIWindowsSmoke: ready")
    event_loop.exit()
  }
}

///|
fn log_surface(window : @windows.Window) -> Unit {
  let size = window.surface_size()
  println(
    "MOUIWindowsSmoke: surface size=\{size.width()}x\{size.height()} scale=\{window.scale_factor()}",
  )
}

///|
fn log_handle(window : @windows.Window) -> Bool {
  let hwnd = window.window_handle()
  println("MOUIWindowsSmoke: handle hwnd=0x\{hwnd.to_string(radix=16)}")
  hwnd != (0 : Int).to_uint64()
}

///|
fn log_monitor_probe(window : @windows.Window) -> Unit {
  let monitors = window.available_monitors()
  let primary = window.primary_monitor()
  let current = window.current_monitor()
  println(
    "MOUIWindowsSmoke: monitors count=\{monitors.length()} primary=\{primary is Some(_)} current=\{current is Some(_)}",
  )
}

///|
fn log_cursor_probe(window : @windows.Window) -> Unit {
  window.set_cursor_icon(Text)
  println("MOUIWindowsSmoke: cursor \{window.cursor()}")
}

///|
pub impl @windows.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  event_loop.set_control_flow(Poll)
  let initial_size : @dpi.PhysicalSize = PhysicalSize(320, 180)
  let attributes = @core.WindowAttributes::default()
    .with_title("MoUI Windows smoke")
    .with_surface_size(initial_size.into_size())
  let window : @windows.Window? = Some(event_loop.try_create_window(attributes)) catch {
    err => {
      println("MOUIWindowsSmoke: create failed \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      self.window = Some(window)
      log_surface(window)
      self.saw_handle = log_handle(window)
      log_monitor_probe(window)
      log_cursor_probe(window)
      let resized_size : @dpi.PhysicalSize = PhysicalSize(400, 240)
      ignore(window.request_surface_size(resized_size.into_size()))
      self.requested_resize = true
      println(
        "MOUIWindowsSmoke: resize requested size=\{resized_size.width()}x\{resized_size.height()}",
      )
      if native_send_input(window.window_handle()) != 0 {
        self.requested_input = true
        println("MOUIWindowsSmoke: input requested")
      } else {
        println("MOUIWindowsSmoke: input request failed")
      }
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @windows.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    SurfaceResized(size) => {
      self.saw_resize = true
      println("MOUIWindowsSmoke: resize size=\{size.width()}x\{size.height()}")
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
      self.maybe_ready(event_loop)
    }
    RedrawRequested => {
      self.saw_redraw = true
      match self.window {
        Some(window) => {
          window.pre_present_notify()
          println("MOUIWindowsSmoke: redraw pre_present_notify")
        }
        None => ()
      }
      self.maybe_ready(event_loop)
    }
    PointerMoved(_, position, _, _) => {
      self.saw_pointer = true
      println("MOUIWindowsSmoke: pointer x=\{position.x()} y=\{position.y()}")
      self.maybe_ready(event_loop)
    }
    KeyboardInput(_, key_event, false) =>
      if key_event.state() is Pressed {
        self.saw_keyboard = true
        println("MOUIWindowsSmoke: keyboard pressed")
        self.maybe_ready(event_loop)
      }
    Ime(Commit(text)) => {
      self.saw_text = true
      println("MOUIWindowsSmoke: ime text=\{text}")
      self.maybe_ready(event_loop)
    }
    Destroyed => println("MOUIWindowsSmoke: destroyed")
    CloseRequested => event_loop.exit()
    _ => ()
  }
}

///|
pub impl @windows.ApplicationHandler for App with fn about_to_wait(
  self,
  event_loop,
) {
  self.wait_count += 1
  match self.window {
    Some(window) => if !self.saw_redraw { window.request_redraw() }
    None => ()
  }
  self.maybe_ready(event_loop)
  if self.wait_count > 500 && !self.ready_printed {
    println(
      "MOUIWindowsSmoke: failed handles=\{self.saw_handle} redraw=\{self.saw_redraw} resize=\{self.saw_resize} pointer=\{self.saw_pointer} keyboard=\{self.saw_keyboard} text=\{self.saw_text} requested_resize=\{self.requested_resize} requested_input=\{self.requested_input}",
    )
    event_loop.exit()
  }
}

///|
fn main {
  let event_loop = @windows.EventLoop::new()
  event_loop.run_app({
    window: None,
    saw_handle: false,
    saw_redraw: false,
    saw_resize: false,
    saw_pointer: false,
    saw_keyboard: false,
    saw_text: false,
    requested_resize: false,
    requested_input: false,
    ready_printed: false,
    wait_count: 0,
  })
  println("MOUIWindowsSmoke: finished")
}
