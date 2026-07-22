///|
struct App {
  mut window : @linux.Window?
  mut saw_handle : Bool
  mut saw_redraw : Bool
  mut saw_resize : Bool
  mut saw_present : Bool
  mut saw_monitor : Bool
  mut saw_cursor : Bool
  mut saw_pointer : Bool
  mut saw_keyboard : Bool
  mut saw_ime_probe : Bool
  mut saw_data_device_probe : Bool
  mut saw_destroyed : Bool
  require_input : Bool
  require_data_device : Bool
  mut core_ready_printed : Bool
  mut destroy_requested : Bool
  mut requested_resize : Bool
  mut ready_printed : Bool
  mut wait_count : Int
}

///|
extern "C" fn native_require_input() -> Int = "mbw_moui_linux_smoke_require_input"

///|
extern "C" fn native_require_data_device() -> Int = "mbw_moui_linux_smoke_require_data_device"

///|
fn App::maybe_ready(self : App, event_loop : @linux.ActiveEventLoop) -> Unit {
  let core_ready = self.saw_handle &&
    self.saw_redraw &&
    self.saw_resize &&
    self.saw_present &&
    self.saw_monitor &&
    self.saw_cursor &&
    self.saw_ime_probe &&
    self.saw_data_device_probe
  let input_ready = self.saw_pointer && self.saw_keyboard
  if !self.ready_printed && core_ready {
    if self.require_input {
      if input_ready {
        self.ready_printed = true
        println("MOUILinuxSmoke: ready input=observed")
        self.request_destroy(event_loop)
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
      self.request_destroy(event_loop)
    }
  }
}

///|
fn App::request_destroy(
  self : App,
  event_loop : @linux.ActiveEventLoop,
) -> Unit {
  if !self.destroy_requested {
    self.destroy_requested = true
    match self.window {
      Some(window) => {
        window.drop()
        self.window = None
        println("MOUILinuxSmoke: destroy requested")
      }
      None => event_loop.exit()
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
fn log_monitor_probe(window : @linux.Window) -> Bool {
  let monitors = window.available_monitors()
  let primary = window.primary_monitor()
  let current = window.current_monitor()
  let primary_id = match primary {
    Some(monitor) => monitor.native_id()
    None => 0UL
  }
  let current_id = match current {
    Some(monitor) => monitor.native_id()
    None => 0UL
  }
  println(
    "MOUILinuxSmoke: monitors count=\{monitors.length()} primary=\{primary is Some(_)} primary_id=0x\{primary_id.to_string(radix=16)} current=\{current is Some(_)} current_id=0x\{current_id.to_string(radix=16)}",
  )
  monitors.length() > 0 &&
  primary is Some(_) &&
  current is Some(_) &&
  primary_id != 0UL &&
  current_id != 0UL
}

///|
fn log_cursor_probe(window : @linux.Window) -> Bool {
  window.set_cursor_icon(Text)
  let cursor = window.cursor()
  println("MOUILinuxSmoke: cursor \{cursor}")
  cursor == Icon(Text)
}

///|
fn log_ime_probe(window : @linux.Window) -> Bool {
  let position : @dpi.Position = @dpi.LogicalPosition::LogicalPosition(
    12.0, 18.0,
  ).into_position()
  let size : @dpi.Size = @dpi.LogicalSize::LogicalSize(2.0, 20.0).into_size()
  let updated_position : @dpi.Position = @dpi.LogicalPosition::LogicalPosition(
    14.0, 20.0,
  ).into_position()
  let updated_size : @dpi.Size = @dpi.LogicalSize::LogicalSize(3.0, 21.0).into_size()
  let surrounding = @core.ImeSurroundingText::ImeSurroundingText("moui", 4, 4) catch {
    _ => {
      println("MOUILinuxSmoke: ime probe surrounding failed")
      return false
    }
  }
  let updated_surrounding = @core.ImeSurroundingText::ImeSurroundingText(
    "moui!", 5, 5,
  ) catch {
    _ => {
      println("MOUILinuxSmoke: ime probe update surrounding failed")
      return false
    }
  }
  let data = @core.ImeRequestData::default()
    .with_hint_and_purpose(@core.ImeHint::completion(), Email)
    .with_surrounding_text(surrounding)
    .with_cursor_area(position, size)
  let update_data = @core.ImeRequestData::default()
    .with_hint_and_purpose(@core.ImeHint::spellcheck(), Url)
    .with_surrounding_text(updated_surrounding)
    .with_cursor_area(updated_position, updated_size)
  let enable = @core.ImeEnableRequest::from_capabilities(
    @core.ImeCapabilities::default()
    .with_hint_and_purpose()
    .with_surrounding_text()
    .with_cursor_area(),
    data,
  )
  guard enable is Some(enable) else {
    println("MOUILinuxSmoke: ime probe enable request failed")
    return false
  }
  window.request_ime_update(Enable(enable)) catch {
    err => {
      println("MOUILinuxSmoke: ime probe enable failed \{err}")
      return false
    }
  }
  let scale = window.scale_factor()
  let expected_position = position.to_physical(scale)
  let expected_size = size.to_physical(scale)
  let enabled = window.ime_capabilities() is Some(_)
  let hint_ok = window.ime_hints().contains(@core.ImeHint::completion()) &&
    window.ime_purpose() == Email
  let surrounding_ok = match window.ime_surrounding_text() {
    Some(text) => text.text() == "moui"
    None => false
  }
  let cursor_ok = window.ime_cursor_area_position() == expected_position &&
    window.ime_cursor_area_size() == expected_size
  window.request_ime_update(Update(update_data)) catch {
    err => {
      println("MOUILinuxSmoke: ime probe update failed \{err}")
      return false
    }
  }
  let expected_updated_position = updated_position.to_physical(scale)
  let expected_updated_size = updated_size.to_physical(scale)
  let updated_hint_ok = window.ime_hints().contains(@core.ImeHint::spellcheck()) &&
    window.ime_purpose() == Url
  let updated_ok = match window.ime_surrounding_text() {
    Some(text) => text.text() == "moui!"
    None => false
  }
  let updated_cursor_ok = window.ime_cursor_area_position() ==
    expected_updated_position &&
    window.ime_cursor_area_size() == expected_updated_size
  window.request_ime_update(Disable) catch {
    err => {
      println("MOUILinuxSmoke: ime probe disable failed \{err}")
      return false
    }
  }
  let disabled = window.ime_capabilities() is None
  println(
    "MOUILinuxSmoke: ime probe enabled=\{enabled} hint=\{hint_ok} surrounding=\{surrounding_ok} cursor=\{cursor_ok} updated=\{updated_ok} updated_hint=\{updated_hint_ok} updated_cursor=\{updated_cursor_ok} disabled=\{disabled}",
  )
  enabled &&
  hint_ok &&
  surrounding_ok &&
  cursor_ok &&
  updated_ok &&
  updated_hint_ok &&
  updated_cursor_ok &&
  disabled
}

///|
fn log_data_device_probe(require_data_device : Bool) -> Bool {
  let clipboard_available = @linux.clipboard_available()
  let drag_drop_available = @linux.drag_drop_available()
  let clipboard_roundtrip = if clipboard_available {
    let text = "MoUI Linux clipboard smoke"
    if @linux.write_clipboard_text(text) {
      match @linux.read_clipboard_text() {
        Some(read) => read == text
        None => false
      }
    } else {
      false
    }
  } else {
    false
  }
  println(
    "MOUILinuxSmoke: data-device clipboard=\{clipboard_available} clipboard_roundtrip=\{clipboard_roundtrip} drag_drop=\{drag_drop_available} require=\{require_data_device}",
  )
  if require_data_device {
    clipboard_available && clipboard_roundtrip && drag_drop_available
  } else {
    true
  }
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
      self.saw_monitor = log_monitor_probe(window)
      self.saw_cursor = log_cursor_probe(window)
      self.saw_ime_probe = log_ime_probe(window)
      self.saw_data_device_probe = log_data_device_probe(
        self.require_data_device,
      )
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
        match key_event.text() {
          Some(text) => {
            println("MOUILinuxSmoke: keyboard text=\{text}")
            if text == "a" {
              self.saw_keyboard = true
            }
          }
          None => println("MOUILinuxSmoke: keyboard pressed")
        }
        self.maybe_ready(event_loop)
      }
    Destroyed => {
      self.saw_destroyed = true
      println("MOUILinuxSmoke: destroyed")
      event_loop.exit()
    }
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
  if self.wait_count > 240 &&
    (!self.ready_printed || (self.destroy_requested && !self.saw_destroyed)) {
    println(
      "MOUILinuxSmoke: failed handles=\{self.saw_handle} monitor=\{self.saw_monitor} cursor=\{self.saw_cursor} redraw=\{self.saw_redraw} resize=\{self.saw_resize} present=\{self.saw_present} pointer=\{self.saw_pointer} keyboard=\{self.saw_keyboard} ime_probe=\{self.saw_ime_probe} data_device_probe=\{self.saw_data_device_probe} requested_resize=\{self.requested_resize} destroy_requested=\{self.destroy_requested} destroyed=\{self.saw_destroyed}",
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
    saw_monitor: false,
    saw_cursor: false,
    saw_pointer: false,
    saw_keyboard: false,
    saw_ime_probe: false,
    saw_data_device_probe: false,
    saw_destroyed: false,
    require_input: native_require_input() != 0,
    require_data_device: native_require_data_device() != 0,
    core_ready_printed: false,
    destroy_requested: false,
    requested_resize: false,
    ready_printed: false,
    wait_count: 0,
  })
  println("MOUILinuxSmoke: finished")
}
