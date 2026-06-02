///|
struct App {
  mut window : @linux.Window?
  mut saw_handle : Bool
  mut saw_redraw : Bool
  mut saw_resize : Bool
  mut saw_present : Bool
  mut saw_pointer : Bool
  mut saw_keyboard : Bool
  require_input : Bool
  mut core_ready_printed : Bool
  mut requested_resize : Bool
  mut ready_printed : Bool
  mut wait_count : Int
}

///|
extern "C" fn native_require_input() -> Int = "mbw_moui_linux_smoke_require_input"

///|
fn App::maybe_ready(self : App, event_loop : @linux.ActiveEventLoop) -> Unit {
  let core_ready = self.saw_handle &&
    self.saw_redraw &&
    self.saw_resize &&
    self.saw_present
  let input_ready = self.saw_pointer && self.saw_keyboard
  if !self.ready_printed && core_ready {
    if self.require_input {
      if input_ready {
        self.ready_printed = true
        println("MOUILinuxSmoke: ready input=observed")
        event_loop.exit()
      } else if !self.core_ready_printed {
        self.core_ready_printed = true
        event_loop.set_control_flow(Wait)
        println("MOUILinuxSmoke: core ready input=required")
      }
    } else {
      self.ready_printed = true
      if input_ready {
        println("MOUILinuxSmoke: ready input=observed")
      } else {
        println("MOUILinuxSmoke: ready input=pending")
      }
      event_loop.exit()
    }
  }
}

///|
fn log_surface(window : @linux.Window) -> Unit {
  let size = window.surface_size()
  println(
    "MOUILinuxSmoke: surface size=\{size.width()}x\{size.height()} scale=\{window.scale_factor()}",
  )
}

///|
fn log_handles(window : @linux.Window) -> Bool {
  let wl_display = window.wl_display()
  let wl_surface = window.wl_surface()
  let xdg_surface = window.xdg_surface()
  let xdg_toplevel = window.xdg_toplevel()
  println(
    "MOUILinuxSmoke: handles wl_display=0x\{wl_display.to_string(radix=16)} wl_surface=0x\{wl_surface.to_string(radix=16)} xdg_surface=0x\{xdg_surface.to_string(radix=16)} xdg_toplevel=0x\{xdg_toplevel.to_string(radix=16)}",
  )
  wl_display != (0 : Int).to_uint64() &&
  wl_surface != (0 : Int).to_uint64() &&
  xdg_surface != (0 : Int).to_uint64() &&
  xdg_toplevel != (0 : Int).to_uint64()
}

///|
fn present_probe(window : @linux.Window) -> Bool {
  let pixels = Bytes::make(16, (0x80 : Int).to_byte())
  let result = window.present_rgba_pixels(2, 2, 8, pixels)
  println("MOUILinuxSmoke: present result=\{result}")
  result == 0
}

///|
fn log_monitor_probe(window : @linux.Window) -> Unit {
  let monitors = window.available_monitors()
  let primary = window.primary_monitor()
  let current = window.current_monitor()
  println(
    "MOUILinuxSmoke: monitors count=\{monitors.length()} primary=\{primary is Some(_)} current=\{current is Some(_)}",
  )
}

///|
fn log_cursor_probe(window : @linux.Window) -> Unit {
  window.set_cursor_icon(Text)
  println("MOUILinuxSmoke: cursor \{window.cursor()}")
}

///|
pub impl @linux.ApplicationHandler for App with fn can_create_surfaces(
  self,
  event_loop,
) {
  event_loop.set_control_flow(Poll)
  let initial_size : @dpi.PhysicalSize = PhysicalSize(320, 180)
  let attributes = @core.WindowAttributes::default()
    .with_title("MoUI Linux smoke")
    .with_surface_size(initial_size.into_size())
  let linux_attributes = @linux.WindowAttributesLinux::default().with_app_id(
    "dev.wzzc.window.moui-linux-smoke",
  )
  let window : @linux.Window? = Some(
    event_loop.try_create_window_with_linux_attributes(
      attributes, linux_attributes,
    ),
  ) catch {
    err => {
      println("MOUILinuxSmoke: create failed \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      self.window = Some(window)
      log_surface(window)
      self.saw_handle = log_handles(window)
      self.saw_present = present_probe(window)
      log_monitor_probe(window)
      log_cursor_probe(window)
      let resized_size : @dpi.PhysicalSize = PhysicalSize(400, 240)
      ignore(window.request_surface_size(resized_size.into_size()))
      self.requested_resize = true
      println(
        "MOUILinuxSmoke: resize requested size=\{resized_size.width()}x\{resized_size.height()}",
      )
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @linux.ApplicationHandler for App with fn window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    SurfaceResized(size) => {
      self.saw_resize = true
      println("MOUILinuxSmoke: resize size=\{size.width()}x\{size.height()}")
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
          println("MOUILinuxSmoke: redraw pre_present_notify")
        }
        None => ()
      }
      self.maybe_ready(event_loop)
    }
    PointerMoved(_, position, _, _) => {
      self.saw_pointer = true
      println("MOUILinuxSmoke: pointer x=\{position.x()} y=\{position.y()}")
      self.maybe_ready(event_loop)
    }
    KeyboardInput(_, key_event, false) =>
      if key_event.state() is Pressed {
        self.saw_keyboard = true
        println("MOUILinuxSmoke: keyboard pressed")
        self.maybe_ready(event_loop)
      }
    Destroyed => println("MOUILinuxSmoke: destroyed")
    CloseRequested => event_loop.exit()
    _ => ()
  }
}

///|
pub impl @linux.ApplicationHandler for App with fn about_to_wait(
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
      "MOUILinuxSmoke: failed handles=\{self.saw_handle} redraw=\{self.saw_redraw} resize=\{self.saw_resize} present=\{self.saw_present} pointer=\{self.saw_pointer} keyboard=\{self.saw_keyboard} requested_resize=\{self.requested_resize}",
    )
    event_loop.exit()
  }
}

///|
fn main {
  let event_loop = @linux.EventLoop::new()
  event_loop.run_app({
    window: None,
    saw_handle: false,
    saw_redraw: false,
    saw_resize: false,
    saw_present: false,
    saw_pointer: false,
    saw_keyboard: false,
    require_input: native_require_input() != 0,
    core_ready_printed: false,
    requested_resize: false,
    ready_printed: false,
    wait_count: 0,
  })
  println("MOUILinuxSmoke: finished")
}
