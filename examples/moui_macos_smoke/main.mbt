///|
struct App {
  mut window : @macos.Window?
  mut saw_handle : Bool
  mut saw_monitor : Bool
  mut saw_cursor : Bool
  mut saw_redraw : Bool
  mut saw_resize : Bool
  mut saw_pointer : Bool
  mut saw_keyboard : Bool
  mut saw_ime : Bool
  mut requested_resize : Bool
  mut requested_input : Bool
  mut ready_printed : Bool
  mut failure_printed : Bool
  mut wait_count : Int
  log_lines : Array[String]
}

///|
extern "C" fn native_send_input(raw_view_handle : UInt64) -> Int = "mbw_moui_macos_smoke_send_input"

///|
fn App::log(self : App, message : String) -> Unit {
  println(message)
  self.log_lines.push(message)
}

///|
fn App::write_log_artifact(self : App) -> Unit {
  match @env.get_env_var("WINDOW_MOUI_MACOS_SMOKE_LOG_PATH") {
    Some(path) =>
      if path != "" {
        let mut output = ""
        for line in self.log_lines {
          output = output + line + "\n"
        }
        @fs.write_bytes_to_file(path, @utf8.encode(output[:], bom=false)) catch {
          _ => println("MOUIMacSmoke: artifact write failed")
        }
      }
    None => ()
  }
}

///|
fn App::maybe_ready(self : App, event_loop : @macos.ActiveEventLoop) -> Unit {
  if !self.ready_printed &&
    self.saw_handle &&
    self.saw_monitor &&
    self.saw_cursor &&
    self.saw_redraw &&
    self.saw_resize &&
    self.saw_pointer &&
    self.saw_keyboard &&
    self.saw_ime {
    self.ready_printed = true
    self.log("MOUIMacSmoke: ready")
    event_loop.exit()
  }
}

///|
fn App::log_surface(self : App, window : @macos.Window) -> Unit {
  let size = window.surface_size()
  self.log(
    "MOUIMacSmoke: surface size=\{size.width()}x\{size.height()} scale=\{window.scale_factor()}",
  )
}

///|
fn App::log_handles(self : App, window : @macos.Window) -> Bool {
  let window_handle = window.window_handle()
  let content_view_handle = window.content_view_handle() catch {
    err => {
      self.log("MOUIMacSmoke: content_view_handle failed \{err}")
      (0 : Int).to_uint64()
    }
  }
  self.log(
    "MOUIMacSmoke: handles window=0x\{window_handle.to_string(radix=16)} content_view=0x\{content_view_handle.to_string(radix=16)}",
  )
  window_handle != (0 : Int).to_uint64() &&
  content_view_handle != (0 : Int).to_uint64()
}

///|
fn App::log_monitor_probe(self : App, window : @macos.Window) -> Bool {
  let monitors = window.available_monitors()
  let primary = window.primary_monitor()
  let current = window.current_monitor()
  self.log(
    "MOUIMacSmoke: monitors count=\{monitors.length()} primary=\{primary is Some(_)} current=\{current is Some(_)}",
  )
  monitors.length() > 0 && primary is Some(_) && current is Some(_)
}

///|
fn App::log_cursor_probe(self : App, window : @macos.Window) -> Bool {
  window.set_cursor_icon(Text)
  self.log("MOUIMacSmoke: cursor \{window.cursor()}")
  window.cursor() == Icon(Text)
}

///|
fn App::log_ime_probe(self : App, window : @macos.Window) -> Bool {
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
      self.log("MOUIMacSmoke: ime probe surrounding failed")
      return false
    }
  }
  let updated_surrounding = @core.ImeSurroundingText::ImeSurroundingText(
    "moui!", 5, 5,
  ) catch {
    _ => {
      self.log("MOUIMacSmoke: ime probe update surrounding failed")
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
    self.log("MOUIMacSmoke: ime probe enable request failed")
    return false
  }
  window.request_ime_update(Enable(enable)) catch {
    err => {
      self.log("MOUIMacSmoke: ime probe enable failed \{err}")
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
      self.log("MOUIMacSmoke: ime probe update failed \{err}")
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
      self.log("MOUIMacSmoke: ime probe disable failed \{err}")
      return false
    }
  }
  let disabled = window.ime_capabilities() is None
  self.log(
    "MOUIMacSmoke: ime probe enabled=\{enabled} hint=\{hint_ok} surrounding=\{surrounding_ok} cursor=\{cursor_ok} updated=\{updated_ok} updated_hint=\{updated_hint_ok} updated_cursor=\{updated_cursor_ok} disabled=\{disabled}",
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
      self.log("MOUIMacSmoke: create failed \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      self.window = Some(window)
      self.log_surface(window)
      self.saw_handle = self.log_handles(window)
      self.saw_monitor = self.log_monitor_probe(window)
      self.saw_cursor = self.log_cursor_probe(window)
      self.saw_ime = self.log_ime_probe(window)
      let resized_size : @dpi.PhysicalSize = PhysicalSize(400, 240)
      ignore(window.request_surface_size(resized_size.into_size()))
      self.requested_resize = true
      self.log(
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
        self.log("MOUIMacSmoke: input requested")
      } else {
        self.log("MOUIMacSmoke: input request failed")
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
      self.log("MOUIMacSmoke: resize size=\{size.width()}x\{size.height()}")
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
      self.maybe_ready(event_loop)
    }
    PointerMoved(_, position, _, _) => {
      self.saw_pointer = true
      self.log("MOUIMacSmoke: pointer x=\{position.x()} y=\{position.y()}")
      self.maybe_ready(event_loop)
    }
    KeyboardInput(_, key_event, false) =>
      if key_event.state() is Pressed {
        self.saw_keyboard = true
        let text = match key_event.text() {
          Some(text) => text
          None => ""
        }
        self.log("MOUIMacSmoke: keyboard text=\{text}")
        self.maybe_ready(event_loop)
      }
    RedrawRequested => {
      self.saw_redraw = true
      match self.window {
        Some(window) => {
          window.pre_present_notify()
          @util.fill_window(window)
          self.log("MOUIMacSmoke: redraw pre_present_notify")
        }
        None => ()
      }
      self.maybe_ready(event_loop)
    }
    Destroyed => self.log("MOUIMacSmoke: destroyed")
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
  if self.wait_count > 240 && !self.ready_printed && !self.failure_printed {
    self.failure_printed = true
    self.log(
      "MOUIMacSmoke: failed handles=\{self.saw_handle} monitor=\{self.saw_monitor} cursor=\{self.saw_cursor} redraw=\{self.saw_redraw} resize=\{self.saw_resize} pointer=\{self.saw_pointer} keyboard=\{self.saw_keyboard} ime=\{self.saw_ime} requested_resize=\{self.requested_resize} requested_input=\{self.requested_input}",
    )
    event_loop.exit()
  }
}

///|
fn main {
  @util.tracing_init()
  let event_loop = @macos.EventLoop::EventLoop()
  let app = {
    window: None,
    saw_handle: false,
    saw_monitor: false,
    saw_cursor: false,
    saw_redraw: false,
    saw_resize: false,
    saw_pointer: false,
    saw_keyboard: false,
    saw_ime: false,
    requested_resize: false,
    requested_input: false,
    ready_printed: false,
    failure_printed: false,
    wait_count: 0,
    log_lines: [],
  }
  event_loop.run_app(app)
  app.log("MOUIMacSmoke: finished")
  app.write_log_artifact()
}
