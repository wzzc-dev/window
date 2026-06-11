///|
pub struct Window {
  priv id : @core.WindowId
  priv hwnd : UInt64
  priv mut cursor_state : @core.Cursor
  priv mut fullscreen_state : @core.Fullscreen?
  priv mut ime_capabilities_state : @core.ImeCapabilities?
  priv mut ime_surrounding_text_state : @core.ImeSurroundingText?
  priv mut ime_cursor_area_position_state : @dpi.PhysicalPosition
  priv mut ime_cursor_area_size_state : @dpi.PhysicalSize
  priv mut is_decorated_state : Bool
  priv mut is_maximized_state : Bool
  priv mut is_visible_state : Bool
  priv mut is_resizable_state : Bool
  priv mut is_cursor_visible_state : Bool
  priv mut is_cursor_hittest_state : Bool
  priv mut is_transparent_state : Bool
  priv mut is_blurred_state : Bool
  priv scale_factor_state : Double
  priv mut saved_window_rect_left : Int
  priv mut saved_window_rect_top : Int
  priv mut saved_window_rect_right : Int
  priv mut saved_window_rect_bottom : Int
  priv mut saved_window_style : UInt64
  priv mut saved_window_ex_style : UInt64
} derive(Eq, Debug)

///|
pub type WindowAttributesWindows = @core.PlatformWindowAttributes

///|
let ws_overlapped : UInt64 = 0x00000000

///|
let ws_popup : UInt64 = 0x80000000

///|
let ws_visible : UInt64 = 0x10000000

///|
let ws_clipsiblings : UInt64 = 0x04000000

///|
let ws_clipchildren : UInt64 = 0x02000000

///|
let ws_caption : UInt64 = 0x00C00000

///|
let ws_sysmenu : UInt64 = 0x00080000

///|
let ws_thickframe : UInt64 = 0x00040000

///|
let ws_minimizebox : UInt64 = 0x00020000

///|
let ws_maximizebox : UInt64 = 0x00010000

///|
let ws_overlappedwindow : UInt64 = ws_overlapped |
  ws_caption |
  ws_sysmenu |
  ws_thickframe |
  ws_minimizebox |
  ws_maximizebox

///|
let ws_ex_layered : UInt64 = 0x00080000

///|
let ws_ex_toolwindow : UInt64 = 0x00000080

///|
let ws_ex_appwindow : UInt64 = 0x00040000

///|
let sw_hide : Int = 0

///|
let sw_shownormal : Int = 1

///|
let sw_maximize : Int = 3

///|
let sw_minimize : Int = 6

///|
let sw_restore : Int = 9

///|
let swp_nomove : UInt64 = 0x0002

///|
let swp_nosize : UInt64 = 0x0001

///|
let swp_nozorder : UInt64 = 0x0004

///|
let swp_noactivate : UInt64 = 0x0010

///|
let swp_framechanged : UInt64 = 0x0020

///|
let hwnd_top : UInt64 = 0

///|
let hwnd_bottom : UInt64 = 1

///|
let hwnd_topmost : UInt64 = (-1L).reinterpret_as_uint64()

///|
let hwnd_notopmost : UInt64 = (-2L).reinterpret_as_uint64()

///|
let size_minimized : Int = 1

///|
let cw_usedefault : Int = -2147483648

///|
let pm_remove : UInt = 1

///|
let tme_leave : UInt = 0x00000002

///|
let htcaption : Int = 2

///|
let wheel_delta : Int = 120

///|
fn compute_window_style(attributes : @core.WindowAttributes) -> UInt64 {
  let mut style = ws_overlappedwindow
  if attributes.decorations() == false {
    style = ws_popup | ws_clipchildren | ws_clipsiblings
  }
  if attributes.resizable() == false {
    style = style & ws_thickframe.lnot() & ws_maximizebox.lnot()
  }
  if attributes.visible() {
    style = style | ws_visible
  }
  style
}

///|
fn compute_window_ex_style(attributes : @core.WindowAttributes) -> UInt64 {
  let mut ex_style = (0 : Int).to_uint64()
  if attributes.transparent() {
    ex_style = ex_style | ws_ex_layered
  }
  if attributes.skip_taskbar() {
    ex_style = ex_style | ws_ex_toolwindow
  }
  let platform_attrs = attributes.platform_attributes()
  if platform_attrs.borderless_game() {
    ex_style = ex_style | ws_ex_appwindow
  }
  ex_style
}

///|
pub fn Window::new(
  event_loop : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  let _ = event_loop
  let raw_id = app_state_next_window_id()
  let window_id = @core.WindowId::from_raw(raw_id)
  let style = compute_window_style(attributes)
  let ex_style = compute_window_ex_style(attributes)
  let scale_factor = 1.0
  let (width, height) = match attributes.surface_size() {
    Some(size) => {
      let physical = size.to_physical(scale_factor)
      (physical.width, physical.height)
    }
    None => (800, 600)
  }
  let (x, y) = match attributes.position() {
    Some(pos) => {
      let physical = pos.to_physical(scale_factor)
      (physical.x, physical.y)
    }
    None => (cw_usedefault, cw_usedefault)
  }
  let parent_hwnd = match attributes.parent_window() {
    Some(parent) => parent.into_raw()
    None => (0 : Int).to_uint64()
  }
  let hwnd = native_create_window(
    width, height, ex_style, style, x, y, parent_hwnd,
  )
  if hwnd == (0 : Int).to_uint64() {
    raise @core.RequestError::os("CreateWindowExW returned a null HWND")
  }
  native_set_window_raw_id(hwnd, raw_id)
  match attributes.title() {
    "" => ()
    title => {
      let title_bytes = @utf8.encode(title, bom=false)
      ignore(native_set_window_text(hwnd, title_bytes, title_bytes.length()))
    }
  }
  if attributes.visible() {
    ignore(native_show_window(hwnd, sw_shownormal))
  }
  app_state_register_window_handle(raw_id, hwnd)
  {
    id: window_id,
    hwnd,
    cursor_state: @core.Cursor::Icon(@core.CursorIcon::Default),
    fullscreen_state: None,
    ime_capabilities_state: None,
    ime_surrounding_text_state: None,
    ime_cursor_area_position_state: @dpi.PhysicalPosition::PhysicalPosition(
      0, 0,
    ),
    ime_cursor_area_size_state: @dpi.PhysicalSize::PhysicalSize(1, 1),
    is_decorated_state: attributes.decorations(),
    is_maximized_state: false,
    is_visible_state: attributes.visible(),
    is_resizable_state: attributes.resizable(),
    is_cursor_visible_state: attributes.cursor_visible(),
    is_cursor_hittest_state: attributes.cursor_hittest(),
    is_transparent_state: attributes.transparent(),
    is_blurred_state: attributes.blur(),
    scale_factor_state: native_get_dpi_for_window(hwnd).to_double() / 96.0,
    saved_window_rect_left: 0,
    saved_window_rect_top: 0,
    saved_window_rect_right: 0,
    saved_window_rect_bottom: 0,
    saved_window_style: 0,
    saved_window_ex_style: 0,
  }
}

///|
pub fn Window::Window(
  event_loop : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  Window::new(event_loop, attributes)
}

///|
pub fn Window::id(self : Window) -> @core.WindowId {
  self.id
}

///|
pub fn Window::drop(self : Window) -> Unit {
  if self.fullscreen_state is Some(_) {
    self.set_fullscreen(None)
  }
  native_destroy_window(self.hwnd)
  app_state_unregister_window_handle(self.id.into_raw())
}

///|
pub fn Window::set_title(self : Window, title : String) -> Unit {
  let title_bytes = @utf8.encode(title, bom=false)
  ignore(native_set_window_text(self.hwnd, title_bytes, title_bytes.length()))
}

///|
pub fn Window::title(self : Window) -> String {
  let _ = self
  "window"
}

///|
pub fn Window::set_visible(self : Window, visible : Bool) -> Unit {
  if visible {
    ignore(native_show_window(self.hwnd, sw_shownormal))
  } else {
    ignore(native_show_window(self.hwnd, sw_hide))
  }
  self.is_visible_state = visible
}

///|
pub fn Window::is_visible(self : Window) -> Bool? {
  Some(native_is_window_visible(self.hwnd) != 0)
}

///|
pub fn Window::inner_size(self : Window) -> @dpi.PhysicalSize {
  let left = native_get_client_rect_left(self.hwnd)
  let top = native_get_client_rect_top(self.hwnd)
  let right = native_get_client_rect_right(self.hwnd)
  let bottom = native_get_client_rect_bottom(self.hwnd)
  @dpi.PhysicalSize::PhysicalSize(right - left, bottom - top)
}

///|
pub fn Window::outer_size(self : Window) -> @dpi.PhysicalSize {
  let left = native_get_window_rect_left(self.hwnd)
  let top = native_get_window_rect_top(self.hwnd)
  let right = native_get_window_rect_right(self.hwnd)
  let bottom = native_get_window_rect_bottom(self.hwnd)
  @dpi.PhysicalSize::PhysicalSize(right - left, bottom - top)
}

///|
pub fn Window::inner_position(self : Window) -> @dpi.PhysicalPosition {
  let left = native_get_client_rect_left(self.hwnd)
  let top = native_get_client_rect_top(self.hwnd)
  let x = native_client_to_screen_x(self.hwnd, left, top)
  let y = native_client_to_screen_y(self.hwnd, left, top)
  @dpi.PhysicalPosition::PhysicalPosition(x, y)
}

///|
#warnings("-unused_error_type")
pub fn Window::outer_position(
  self : Window,
) -> @dpi.PhysicalPosition raise @core.RequestError {
  let left = native_get_window_rect_left(self.hwnd)
  let top = native_get_window_rect_top(self.hwnd)
  @dpi.PhysicalPosition::PhysicalPosition(left, top)
}

///|
pub fn Window::set_outer_position(
  self : Window,
  position : @dpi.Position,
) -> Unit {
  let physical = position.to_physical(self.scale_factor())
  ignore(
    native_set_window_pos(
      self.hwnd,
      hwnd_top,
      physical.x,
      physical.y,
      0,
      0,
      swp_nosize | swp_nozorder,
    ),
  )
}

///|
pub fn Window::request_inner_size(
  self : Window,
  size : @dpi.Size,
) -> @dpi.PhysicalSize? {
  let physical = size.to_physical(self.scale_factor())
  ignore(
    native_set_window_pos(
      self.hwnd,
      hwnd_top,
      0,
      0,
      physical.width,
      physical.height,
      swp_nomove | swp_nozorder,
    ),
  )
  None
}

///|
pub fn Window::request_surface_size(
  self : Window,
  size : @dpi.Size,
) -> @dpi.PhysicalSize? {
  self.request_inner_size(size)
}

///|
pub fn Window::surface_size(self : Window) -> @dpi.PhysicalSize {
  self.inner_size()
}

///|
pub fn Window::surface_position(self : Window) -> @dpi.PhysicalPosition {
  self.inner_position()
}

///|
pub fn Window::request_redraw(self : Window) -> Unit {
  ignore(native_invalidate_rect(self.hwnd, false))
}

///|
pub fn Window::pre_present_notify(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::set_resizable(self : Window, resizable : Bool) -> Unit {
  let style = native_get_window_long_style(self.hwnd)
  if resizable {
    ignore(
      native_set_window_long_style(
        self.hwnd,
        style | ws_thickframe | ws_maximizebox,
      ),
    )
  } else {
    ignore(
      native_set_window_long_style(
        self.hwnd,
        style & ws_thickframe.lnot() & ws_maximizebox.lnot(),
      ),
    )
  }
  ignore(
    native_set_window_pos(
      self.hwnd,
      hwnd_top,
      0,
      0,
      0,
      0,
      swp_nomove | swp_nosize | swp_nozorder | swp_framechanged,
    ),
  )
  self.is_resizable_state = resizable
}

///|
pub fn Window::is_resizable(self : Window) -> Bool {
  self.is_resizable_state
}

///|
pub fn Window::set_decorations(self : Window, decorations : Bool) -> Unit {
  if decorations {
    ignore(native_set_window_long_style(self.hwnd, ws_overlappedwindow))
  } else {
    ignore(
      native_set_window_long_style(
        self.hwnd,
        ws_popup | ws_clipchildren | ws_clipsiblings,
      ),
    )
  }
  ignore(
    native_set_window_pos(
      self.hwnd,
      hwnd_top,
      0,
      0,
      0,
      0,
      swp_nomove | swp_nosize | swp_nozorder | swp_framechanged,
    ),
  )
  self.is_decorated_state = decorations
}

///|
pub fn Window::is_decorated(self : Window) -> Bool {
  self.is_decorated_state
}

///|
pub fn Window::set_minimized(self : Window, minimized : Bool) -> Unit {
  if minimized {
    ignore(native_show_window(self.hwnd, sw_minimize))
  } else {
    ignore(native_show_window(self.hwnd, sw_restore))
  }
}

///|
pub fn Window::is_minimized(self : Window) -> Bool? {
  Some(native_is_iconic(self.hwnd) != 0)
}

///|
pub fn Window::set_maximized(self : Window, maximized : Bool) -> Unit {
  if maximized {
    ignore(native_show_window(self.hwnd, sw_maximize))
  } else {
    ignore(native_show_window(self.hwnd, sw_restore))
  }
  self.is_maximized_state = maximized
}

///|
pub fn Window::is_maximized(self : Window) -> Bool {
  native_is_zoomed(self.hwnd) != 0
}

///|
pub fn Window::scale_factor(self : Window) -> Double {
  native_get_dpi_for_window(self.hwnd).to_double() / 96.0
}

///|
pub fn Window::set_cursor_icon(
  self : Window,
  cursor : @core.CursorIcon,
) -> Unit {
  let cursor_handle = cursor_icon_to_native(cursor)
  ignore(native_set_window_cursor(self.hwnd, cursor_handle))
  self.cursor_state = @core.Cursor::Icon(cursor)
}

///|
pub fn Window::set_cursor(self : Window, cursor : @core.Cursor) -> Unit {
  match cursor {
    @core.Cursor::Icon(icon) => self.set_cursor_icon(icon)
    @core.Cursor::Custom(_custom) => ()
  }
  self.cursor_state = cursor
}

///|
pub fn Window::cursor(self : Window) -> @core.Cursor {
  self.cursor_state
}

///|
pub fn Window::set_cursor_visible(self : Window, visible : Bool) -> Unit {
  self.is_cursor_visible_state = visible
}

///|
pub fn Window::is_cursor_visible(self : Window) -> Bool {
  self.is_cursor_visible_state
}

///|
#warnings("-unused_error_type")
pub fn Window::set_cursor_hittest(
  self : Window,
  hittest : Bool,
) -> Unit raise @core.RequestError {
  self.is_cursor_hittest_state = hittest
}

///|
pub fn Window::is_cursor_hittest(self : Window) -> Bool {
  self.is_cursor_hittest_state
}

///|
pub fn Window::set_cursor_grab(
  self : Window,
  mode : @core.CursorGrabMode,
) -> Unit raise @core.RequestError {
  match mode {
    @core.CursorGrabMode::None => ignore(native_clip_cursor(0, 0, 0, 0))
    @core.CursorGrabMode::Locked => {
      let left = native_get_client_rect_left(self.hwnd)
      let top = native_get_client_rect_top(self.hwnd)
      let right = native_get_client_rect_right(self.hwnd)
      let bottom = native_get_client_rect_bottom(self.hwnd)
      ignore(native_clip_cursor(left, top, right, bottom))
    }
    @core.CursorGrabMode::Confined =>
      raise @core.RequestError::not_supported(
        "Windows confined cursor grab is not supported yet",
      )
  }
}

///|
#warnings("-unused_error_type")
pub fn Window::set_cursor_position(
  self : Window,
  position : @dpi.Position,
) -> Unit raise @core.RequestError {
  let physical = position.to_physical(self.scale_factor())
  ignore(native_set_cursor_pos(physical.x, physical.y))
}

///|
pub fn Window::focus_window(self : Window) -> Unit {
  ignore(native_set_foreground_window(self.hwnd))
}

///|
pub fn Window::has_focus(self : Window) -> Bool {
  native_get_foreground_window() == self.hwnd
}

///|
pub fn Window::set_fullscreen(
  self : Window,
  fullscreen : @core.Fullscreen?,
) -> Unit {
  match fullscreen {
    None =>
      if self.fullscreen_state is Some(_) {
        ignore(native_set_window_long_style(self.hwnd, self.saved_window_style))
        ignore(
          native_set_window_long_ex_style(self.hwnd, self.saved_window_ex_style),
        )
        ignore(
          native_set_window_pos(
            self.hwnd,
            hwnd_notopmost,
            self.saved_window_rect_left,
            self.saved_window_rect_top,
            self.saved_window_rect_right - self.saved_window_rect_left,
            self.saved_window_rect_bottom - self.saved_window_rect_top,
            swp_noactivate | swp_framechanged,
          ),
        )
        self.fullscreen_state = None
      }
    Some(fs) => {
      self.saved_window_rect_left = native_get_window_rect_left(self.hwnd)
      self.saved_window_rect_top = native_get_window_rect_top(self.hwnd)
      self.saved_window_rect_right = native_get_window_rect_right(self.hwnd)
      self.saved_window_rect_bottom = native_get_window_rect_bottom(self.hwnd)
      self.saved_window_style = native_get_window_long_style(self.hwnd)
      self.saved_window_ex_style = native_get_window_long_ex_style(self.hwnd)
      let screen_w = native_get_system_metrics(0)
      let screen_h = native_get_system_metrics(1)
      ignore(
        native_set_window_long_style(
          self.hwnd,
          ws_popup | ws_clipchildren | ws_clipsiblings,
        ),
      )
      ignore(
        native_set_window_pos(
          self.hwnd,
          hwnd_topmost,
          0,
          0,
          screen_w,
          screen_h,
          swp_noactivate | swp_framechanged,
        ),
      )
      self.fullscreen_state = Some(fs)
    }
  }
}

///|
pub fn Window::fullscreen(self : Window) -> @core.Fullscreen? {
  self.fullscreen_state
}

///|
pub fn Window::is_fullscreen(self : Window) -> Bool {
  self.fullscreen_state is Some(_)
}

///|
pub fn Window::set_window_level(
  self : Window,
  level : @core.WindowLevel,
) -> Unit {
  let insert_after = match level {
    @core.WindowLevel::Normal => hwnd_notopmost
    @core.WindowLevel::AlwaysOnTop => hwnd_topmost
    @core.WindowLevel::AlwaysOnBottom => hwnd_bottom
  }
  ignore(
    native_set_window_pos(
      self.hwnd,
      insert_after,
      0,
      0,
      0,
      0,
      swp_nomove | swp_nosize | swp_noactivate,
    ),
  )
}

///|
pub fn Window::window_level(self : Window) -> @core.WindowLevel {
  let ex_style = native_get_window_long_ex_style(self.hwnd)
  if (ex_style & (8 : Int).to_uint64()) != (0 : Int).to_uint64() {
    @core.WindowLevel::AlwaysOnTop
  } else {
    @core.WindowLevel::Normal
  }
}

///|
pub fn Window::set_enabled_buttons(
  self : Window,
  _buttons : @core.WindowButtons,
) -> Unit {
  let _ = self
}

///|
pub fn Window::enabled_buttons(self : Window) -> @core.WindowButtons {
  let _ = self
  @core.WindowButtons::all()
}

///|
pub fn Window::set_content_protected(
  self : Window,
  is_protected : Bool,
) -> Unit {
  let _ = self
  let _ = is_protected
}

///|
pub fn Window::is_content_protected(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::set_skip_taskbar(self : Window, skip : Bool) -> Unit {
  let ex_style = native_get_window_long_ex_style(self.hwnd)
  if skip {
    ignore(
      native_set_window_long_ex_style(self.hwnd, ex_style | ws_ex_toolwindow),
    )
  } else {
    ignore(
      native_set_window_long_ex_style(
        self.hwnd,
        ex_style & ws_ex_toolwindow.lnot(),
      ),
    )
  }
}

///|
pub fn Window::set_ime_allowed(self : Window, allowed : Bool) -> Unit {
  if allowed {
    self.ime_capabilities_state = Some(
      @core.ImeCapabilities::default()
      .with_hint_and_purpose()
      .with_cursor_area()
      .with_surrounding_text(),
    )
  } else {
    self.ime_capabilities_state = None
    self.ime_surrounding_text_state = None
    self.ime_cursor_area_position_state = @dpi.PhysicalPosition::PhysicalPosition(
      0, 0,
    )
    self.ime_cursor_area_size_state = @dpi.PhysicalSize::PhysicalSize(1, 1)
  }
}

///|
pub fn Window::ime_allowed(self : Window) -> Bool {
  self.ime_capabilities_state is Some(_)
}

///|
pub fn Window::set_ime_cursor_area(
  self : Window,
  position : @dpi.Position,
  size : @dpi.Size,
) -> Unit {
  let physical_position = position.to_physical(self.scale_factor())
  let physical_size = size.to_physical(self.scale_factor())
  let width = if physical_size.width() > 0 { physical_size.width() } else { 1 }
  let height = if physical_size.height() > 0 {
    physical_size.height()
  } else {
    1
  }
  self.ime_cursor_area_position_state = physical_position
  self.ime_cursor_area_size_state = @dpi.PhysicalSize::PhysicalSize(
    width, height,
  )
}

///|
pub fn Window::ime_cursor_area_position(self : Window) -> @dpi.PhysicalPosition {
  self.ime_cursor_area_position_state
}

///|
pub fn Window::ime_cursor_area_size(self : Window) -> @dpi.PhysicalSize {
  self.ime_cursor_area_size_state
}

///|
pub fn Window::set_ime_hints(self : Window, hints : @core.ImeHint) -> Unit {
  let _ = self
  let _ = hints
}

///|
pub fn Window::ime_hints(self : Window) -> @core.ImeHint {
  let _ = self
  @core.ImeHint::none()
}

///|
pub fn Window::set_ime_purpose(
  self : Window,
  purpose : @core.ImePurpose,
) -> Unit {
  let _ = self
  let _ = purpose
}

///|
pub fn Window::ime_purpose(self : Window) -> @core.ImePurpose {
  let _ = self
  @core.ImePurpose::Normal
}

///|
pub fn Window::request_ime_update(
  self : Window,
  request : @core.ImeRequest,
) -> Unit raise @core.ImeRequestError {
  match request {
    @core.ImeRequest::Enable(enable_request) =>
      match self.ime_capabilities_state {
        Some(_) => raise @core.ImeRequestError::AlreadyEnabled
        None => {
          self.ime_capabilities_state = Some(enable_request.capabilities())
          self.apply_ime_request_data(enable_request.request_data())
        }
      }
    @core.ImeRequest::Update(request_data) =>
      match self.ime_capabilities_state {
        Some(_) => self.apply_ime_request_data(request_data)
        None => raise @core.ImeRequestError::NotEnabled
      }
    @core.ImeRequest::Disable => self.set_ime_allowed(false)
  }
}

///|
pub fn Window::ime_capabilities(self : Window) -> @core.ImeCapabilities? {
  self.ime_capabilities_state
}

///|
pub fn Window::set_ime_surrounding_text(
  self : Window,
  text : @core.ImeSurroundingText?,
) -> Unit {
  self.ime_surrounding_text_state = text
}

///|
pub fn Window::ime_surrounding_text(self : Window) -> @core.ImeSurroundingText? {
  self.ime_surrounding_text_state
}

///|
fn Window::apply_ime_request_data(
  self : Window,
  request_data : @core.ImeRequestData,
) -> Unit {
  match request_data.surrounding_text() {
    Some(text) => self.ime_surrounding_text_state = Some(text)
    None => ()
  }
  match request_data.cursor_area() {
    Some((position, size)) => self.set_ime_cursor_area(position, size)
    None => ()
  }
}

///|
pub fn Window::set_has_shadow(self : Window, shadow : Bool) -> Unit {
  let _ = self
  let _ = shadow
}

///|
pub fn Window::has_shadow(self : Window) -> Bool {
  let _ = self
  true
}

///|
pub fn Window::set_blur(self : Window, blur : Bool) -> Unit {
  self.is_blurred_state = blur
}

///|
pub fn Window::is_blurred(self : Window) -> Bool {
  self.is_blurred_state
}

///|
pub fn Window::set_transparent(self : Window, transparent : Bool) -> Unit {
  self.is_transparent_state = transparent
}

///|
pub fn Window::is_transparent(self : Window) -> Bool {
  self.is_transparent_state
}

///|
pub fn Window::set_theme(self : Window, theme : @core.Theme?) -> Unit {
  let _ = self
  let _ = theme
}

///|
pub fn Window::theme(self : Window) -> @core.Theme? {
  let _ = self
  theme_from_native(native_system_theme())
}

///|
#warnings("-unused_error_type")
pub fn Window::drag_window(self : Window) -> Unit raise @core.RequestError {
  native_release_capture()
  ignore(native_send_message(self.hwnd, 0x00A1, htcaption.to_uint64(), 0))
}

///|
#warnings("-unused_error_type")
pub fn Window::drag_resize_window(
  self : Window,
  direction : @core.ResizeDirection,
) -> Unit raise @core.RequestError {
  native_release_capture()
  let hit_test = match direction {
    @core.ResizeDirection::East => 11
    @core.ResizeDirection::North => 12
    @core.ResizeDirection::NorthEast => 14
    @core.ResizeDirection::NorthWest => 13
    @core.ResizeDirection::South => 15
    @core.ResizeDirection::SouthEast => 17
    @core.ResizeDirection::SouthWest => 16
    @core.ResizeDirection::West => 10
  }
  ignore(native_send_message(self.hwnd, 0x00A1, hit_test.to_uint64(), 0))
}

///|
pub fn Window::request_user_attention(
  self : Window,
  _attention_type : @core.UserAttentionType?,
) -> Unit {
  let _ = self
}

///|
pub fn Window::reset_dead_keys(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::display_handle(self : Window) -> UInt64 {
  let _ = self
  (0 : Int).to_uint64()
}

///|
pub fn Window::window_handle(self : Window) -> UInt64 {
  self.hwnd
}

///|
pub fn Window::rwh_06_display_handle(self : Window) -> UInt64 {
  let _ = self
  (0 : Int).to_uint64()
}

///|
pub fn Window::rwh_06_window_handle(self : Window) -> UInt64 {
  self.hwnd
}

///|
pub fn Window::is_occluded(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::is_borderless_game(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::set_borderless_game(self : Window, borderless : Bool) -> Unit {
  let _ = self
  let _ = borderless
}

///|
pub fn Window::option_as_alt(self : Window) -> @core.OptionAsAlt {
  let _ = self
  @core.OptionAsAlt::None
}

///|
pub fn Window::set_option_as_alt(
  self : Window,
  option_as_alt : @core.OptionAsAlt,
) -> Unit {
  let _ = self
  let _ = option_as_alt
}

///|
pub fn Window::unified_titlebar(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::set_unified_titlebar(self : Window, unified : Bool) -> Unit {
  let _ = self
  let _ = unified
}

///|
pub fn Window::set_simple_fullscreen(self : Window, _simple : Bool) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::simple_fullscreen(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::set_window_icon(self : Window, _icon : @core.Icon?) -> Unit {
  let _ = self
}

///|
pub fn Window::set_min_inner_size(self : Window, _size : @dpi.Size?) -> Unit {
  let _ = self
}

///|
pub fn Window::set_max_inner_size(self : Window, _size : @dpi.Size?) -> Unit {
  let _ = self
}

///|
pub fn Window::set_min_surface_size(self : Window, _size : @dpi.Size?) -> Unit {
  let _ = self
}

///|
pub fn Window::set_max_surface_size(self : Window, _size : @dpi.Size?) -> Unit {
  let _ = self
}

///|
pub fn Window::min_inner_size(self : Window) -> @dpi.PhysicalSize? {
  let _ = self
  None
}

///|
pub fn Window::max_inner_size(self : Window) -> @dpi.PhysicalSize? {
  let _ = self
  None
}

///|
pub fn Window::min_surface_size(self : Window) -> @dpi.PhysicalSize? {
  let _ = self
  None
}

///|
pub fn Window::max_surface_size(self : Window) -> @dpi.PhysicalSize? {
  let _ = self
  None
}

///|
pub fn Window::resize_increments(self : Window) -> @dpi.PhysicalSize? {
  let _ = self
  None
}

///|
pub fn Window::set_resize_increments(
  self : Window,
  _increments : @dpi.Size?,
) -> Unit {
  let _ = self
}

///|
pub fn Window::surface_resize_increments(self : Window) -> @dpi.PhysicalSize? {
  let _ = self
  None
}

///|
pub fn Window::set_surface_resize_increments(
  self : Window,
  _increments : @dpi.Size?,
) -> Unit {
  let _ = self
}

///|
pub fn Window::safe_area(self : Window) -> @dpi.PhysicalInsets {
  let _ = self
  @dpi.PhysicalInsets::PhysicalInsets(0, 0, 0, 0)
}

///|
pub fn Window::set_tabbing_identifier(
  self : Window,
  _identifier : String,
) -> Unit {
  let _ = self
}

///|
pub fn Window::tabbing_identifier(self : Window) -> String {
  let _ = self
  ""
}

///|
pub fn Window::select_next_tab(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::select_previous_tab(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::select_tab_at_index(self : Window, _index : Int) -> Unit {
  let _ = self
}

///|
pub fn Window::num_tabs(self : Window) -> Int {
  let _ = self
  0
}

///|
pub fn Window::set_prefers_home_indicator_hidden(
  self : Window,
  _hidden : Bool,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_prefers_status_bar_hidden(
  self : Window,
  _hidden : Bool,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_preferred_screen_edges_deferring_system_gestures(
  self : Window,
  _edges : @core.ScreenEdge,
) -> Unit {
  let _ = self
}

///|
pub fn Window::show_window_menu(
  self : Window,
  _position : @dpi.Position,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_document_edited(self : Window, edited : Bool) -> Unit {
  let _ = self
  let _ = edited
}

///|
pub fn Window::is_document_edited(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::current_monitor(self : Window) -> @core.MonitorHandle? {
  let _ = self
  None
}

///|
pub fn Window::available_monitors(self : Window) -> Array[@core.MonitorHandle] {
  let _ = self
  available_monitors()
}

///|
pub fn Window::primary_monitor(self : Window) -> @core.MonitorHandle? {
  let _ = self
  primary_monitor()
}

///|
fn cursor_icon_to_native(icon : @core.CursorIcon) -> UInt64 {
  let name = match icon {
    @core.CursorIcon::Default => (32512 : Int).to_uint64()
    @core.CursorIcon::Pointer => (32649 : Int).to_uint64()
    @core.CursorIcon::Text => (32513 : Int).to_uint64()
    @core.CursorIcon::Crosshair => (32515 : Int).to_uint64()
    @core.CursorIcon::Move => (32649 : Int).to_uint64()
    @core.CursorIcon::Wait => (32514 : Int).to_uint64()
    @core.CursorIcon::Progress => (32650 : Int).to_uint64()
    @core.CursorIcon::Help => (32651 : Int).to_uint64()
    @core.CursorIcon::NotAllowed => (32648 : Int).to_uint64()
    @core.CursorIcon::Grab => (32649 : Int).to_uint64()
    @core.CursorIcon::Grabbing => (32649 : Int).to_uint64()
    @core.CursorIcon::EResize => (32643 : Int).to_uint64()
    @core.CursorIcon::NResize => (32645 : Int).to_uint64()
    @core.CursorIcon::NeResize => (32642 : Int).to_uint64()
    @core.CursorIcon::NwResize => (32644 : Int).to_uint64()
    @core.CursorIcon::SResize => (32646 : Int).to_uint64()
    @core.CursorIcon::SeResize => (32642 : Int).to_uint64()
    @core.CursorIcon::SwResize => (32644 : Int).to_uint64()
    @core.CursorIcon::WResize => (32643 : Int).to_uint64()
    @core.CursorIcon::EwResize => (32644 : Int).to_uint64()
    @core.CursorIcon::NsResize => (32645 : Int).to_uint64()
    @core.CursorIcon::NeswResize => (32642 : Int).to_uint64()
    @core.CursorIcon::NwseResize => (32642 : Int).to_uint64()
    @core.CursorIcon::ColResize => (32644 : Int).to_uint64()
    @core.CursorIcon::RowResize => (32645 : Int).to_uint64()
    @core.CursorIcon::AllScroll => (32649 : Int).to_uint64()
    @core.CursorIcon::ZoomIn => (32512 : Int).to_uint64()
    @core.CursorIcon::ZoomOut => (32512 : Int).to_uint64()
    @core.CursorIcon::ContextMenu => (32651 : Int).to_uint64()
    @core.CursorIcon::Cell => (32513 : Int).to_uint64()
    @core.CursorIcon::VerticalText => (32513 : Int).to_uint64()
    @core.CursorIcon::Alias => (32512 : Int).to_uint64()
    @core.CursorIcon::Copy => (32512 : Int).to_uint64()
    @core.CursorIcon::NoDrop => (32648 : Int).to_uint64()
  }
  native_load_cursor((0 : Int).to_uint64(), name)
}
