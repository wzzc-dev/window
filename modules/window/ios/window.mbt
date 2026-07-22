///|
pub struct Window {
  priv id_ : @core.WindowId
  priv mut surface_handle_ : UInt64
  priv mut surface_token_ : UInt64
  priv mut cursor_visible_state : Bool
  priv mut cursor_hittest_state : Bool
  priv mut transparent_state : Bool
  priv mut blur_state : Bool
  priv mut decorated_state : Bool
  priv mut enabled_buttons_state : @core.WindowButtons
  priv mut window_level_state : @core.WindowLevel
  priv mut theme_state : @core.Theme?
  priv mut ime_allowed_state : Bool
  priv mut ime_capabilities_state : @core.ImeCapabilities?
  priv mut ime_hints_state : @core.ImeHint
  priv mut ime_purpose_state : @core.ImePurpose
  priv mut ime_surrounding_text_state : @core.ImeSurroundingText?
}

///|
pub impl Eq for Window with fn equal(self, other) {
  self.id_ == other.id_
}

///|
pub fn Window::new(
  event_loop : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  Window::new_with_ios_attributes(
    event_loop,
    attributes,
    WindowAttributesiOS::default(),
  )
}

///|
pub fn Window::Window(
  event_loop : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  Window::new(event_loop, attributes)
}

///|
pub fn Window::new_with_ios_attributes(
  _event_loop : EventLoop,
  attributes : @core.WindowAttributes,
  platform_attributes : WindowAttributesiOS,
) -> Window raise @core.RequestError {
  let scale = platform_attributes.scale_factor()
  let size = match attributes.surface_size() {
    Some(size) => size.to_physical(scale)
    None =>
      platform_nonzero_size(
        platform_attributes.width(),
        platform_attributes.height(),
      )
  }
  let entry = app_state_create_window_entry(
    attributes.title(),
    size.width,
    size.height,
    scale,
    platform_attributes.surface_handle(),
    platform_attributes.surface_token(),
  )
  let window = {
    id_: @core.WindowId::from_raw(entry.raw_id),
    surface_handle_: platform_attributes.surface_handle(),
    surface_token_: platform_attributes.surface_token(),
    cursor_visible_state: true,
    cursor_hittest_state: true,
    transparent_state: attributes.transparent(),
    blur_state: false,
    decorated_state: attributes.decorations(),
    enabled_buttons_state: attributes.enabled_buttons(),
    window_level_state: attributes.window_level(),
    theme_state: attributes.theme(),
    ime_allowed_state: false,
    ime_capabilities_state: None,
    ime_hints_state: @core.ImeHint::none(),
    ime_purpose_state: @core.ImePurpose::Normal,
    ime_surrounding_text_state: None,
  }
  app_state_queue_window_event(window.id_, SurfaceResized(size))
  app_state_request_redraw(entry.raw_id)
  window
}

///|
fn Window::raw_id(self : Window) -> Int {
  self.id_.into_raw()
}

///|
pub fn Window::id(self : Window) -> @core.WindowId {
  self.id_
}

///|
pub fn Window::drop(self : Window) -> Unit {
  app_state_queue_window_event(self.id_, Destroyed)
  app_state_unregister_window(self.raw_id())
}

///|
pub fn Window::set_title(self : Window, title : String) -> Unit {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.title = title
    None => ()
  }
}

///|
pub fn Window::title(self : Window) -> String {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.title
    None => ""
  }
}

///|
pub fn Window::set_visible(self : Window, visible : Bool) -> Unit {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.visible = visible
    None => ()
  }
}

///|
pub fn Window::is_visible(self : Window) -> Bool? {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => Some(entry.visible)
    None => None
  }
}

///|
pub fn Window::inner_size(self : Window) -> @dpi.PhysicalSize {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => platform_nonzero_size(entry.width, entry.height)
    None => platform_nonzero_size(1, 1)
  }
}

///|
pub fn Window::outer_size(self : Window) -> @dpi.PhysicalSize {
  self.inner_size()
}

///|
pub fn Window::surface_size(self : Window) -> @dpi.PhysicalSize {
  self.inner_size()
}

///|
pub fn Window::inner_position(___self : Window) -> @dpi.PhysicalPosition {
  PhysicalPosition(0, 0)
}

///|
pub fn Window::surface_position(self : Window) -> @dpi.PhysicalPosition {
  self.inner_position()
}

///|
#warnings("-unused_error_type")
pub fn Window::outer_position(
  self : Window,
) -> @dpi.PhysicalPosition raise @core.RequestError {
  self.inner_position()
}

///|
pub fn Window::set_outer_position(
  self : Window,
  _position : @dpi.Position,
) -> Unit {
  let _ = self
}

///|
pub fn Window::request_inner_size(
  self : Window,
  size : @dpi.Size,
) -> @dpi.PhysicalSize? {
  let scale = self.scale_factor()
  let physical = size.to_physical(scale)
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => {
      entry.width = physical.width
      entry.height = physical.height
    }
    None => ()
  }
  app_state_queue_window_event(self.id_, SurfaceResized(physical))
  app_state_request_redraw(self.raw_id())
  Some(physical)
}

///|
pub fn Window::request_surface_size(
  self : Window,
  size : @dpi.Size,
) -> @dpi.PhysicalSize? {
  self.request_inner_size(size)
}

///|
pub fn Window::request_redraw(self : Window) -> Unit {
  app_state_request_redraw(self.raw_id())
}

///|
pub fn Window::pre_present_notify(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::set_resizable(self : Window, resizable : Bool) -> Unit {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.resizable = resizable
    None => ()
  }
}

///|
pub fn Window::is_resizable(self : Window) -> Bool {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.resizable
    None => true
  }
}

///|
pub fn Window::set_enabled_buttons(
  self : Window,
  buttons : @core.WindowButtons,
) -> Unit {
  self.enabled_buttons_state = buttons
}

///|
pub fn Window::enabled_buttons(self : Window) -> @core.WindowButtons {
  self.enabled_buttons_state
}

///|
pub fn Window::set_minimized(self : Window, _minimized : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_minimized(___self : Window) -> Bool? {
  Some(false)
}

///|
pub fn Window::set_maximized(self : Window, _maximized : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_maximized(___self : Window) -> Bool {
  false
}

///|
pub fn Window::set_fullscreen(
  self : Window,
  fullscreen : @core.Fullscreen?,
) -> Unit {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.fullscreen = fullscreen
    None => ()
  }
}

///|
pub fn Window::fullscreen(self : Window) -> @core.Fullscreen? {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.fullscreen
    None => None
  }
}

///|
pub fn Window::set_decorations(self : Window, decorated : Bool) -> Unit {
  self.decorated_state = decorated
}

///|
pub fn Window::is_decorated(self : Window) -> Bool {
  self.decorated_state
}

///|
pub fn Window::set_window_level(
  self : Window,
  level : @core.WindowLevel,
) -> Unit {
  self.window_level_state = level
}

///|
pub fn Window::set_window_icon(self : Window, _icon : @core.Icon?) -> Unit {
  let _ = self
}

///|
pub fn Window::set_ime_cursor_area(
  self : Window,
  _position : @dpi.Position,
  _size : @dpi.Size,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_ime_allowed(self : Window, allowed : Bool) -> Unit {
  self.ime_allowed_state = allowed
}

///|
pub fn Window::ime_allowed(self : Window) -> Bool {
  self.ime_allowed_state
}

///|
pub fn Window::set_ime_purpose(
  self : Window,
  purpose : @core.ImePurpose,
) -> Unit {
  self.ime_purpose_state = purpose
}

///|
pub fn Window::ime_purpose(self : Window) -> @core.ImePurpose {
  self.ime_purpose_state
}

///|
pub fn Window::set_ime_hints(self : Window, hints : @core.ImeHint) -> Unit {
  self.ime_hints_state = hints
}

///|
pub fn Window::ime_hints(self : Window) -> @core.ImeHint {
  self.ime_hints_state
}

///|
pub fn Window::set_ime_capabilities(
  self : Window,
  capabilities : @core.ImeCapabilities?,
) -> Unit {
  self.ime_capabilities_state = capabilities
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
pub fn Window::focus_window(self : Window) -> Unit {
  app_state_queue_window_event(self.id_, Focused(true))
}

///|
pub fn Window::has_focus(___self : Window) -> Bool {
  true
}

///|
pub fn Window::request_user_attention(
  self : Window,
  _attention : @core.UserAttentionType?,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_theme(self : Window, theme : @core.Theme?) -> Unit {
  self.theme_state = theme
}

///|
pub fn Window::theme(self : Window) -> @core.Theme? {
  self.theme_state
}

///|
pub fn Window::set_content_protected(self : Window, _protected : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::set_cursor(self : Window, cursor : @core.Cursor) -> Unit {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.cursor = cursor
    None => ()
  }
}

///|
pub fn Window::cursor(self : Window) -> @core.Cursor {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.cursor
    None => Icon(Default)
  }
}

///|
pub fn Window::set_cursor_visible(self : Window, visible : Bool) -> Unit {
  self.cursor_visible_state = visible
}

///|
pub fn Window::set_cursor_grab(
  self : Window,
  mode : @core.CursorGrabMode,
) -> Unit raise @core.RequestError {
  let _ = self
  match mode {
    None => ()
    Locked | Confined =>
      raise @core.RequestError::not_supported(
        "mobile cursor grab only supports CursorGrabMode::None",
      )
  }
}

///|
pub fn Window::set_cursor_position(
  __self : Window,
  _position : @dpi.Position,
) -> Unit raise @core.RequestError {
  raise @core.RequestError::not_supported(
    "iOS cursor positioning is not supported",
  )
}

///|
pub fn Window::set_cursor_hittest(self : Window, hittest : Bool) -> Unit {
  self.cursor_hittest_state = hittest
}

///|
pub fn Window::drag_window(___self : Window) -> Unit raise @core.RequestError {
  raise @core.RequestError::not_supported(
    "iOS drag-window requests are not supported",
  )
}

///|
pub fn Window::drag_resize_window(
  __self : Window,
  _direction : @core.ResizeDirection,
) -> Unit raise @core.RequestError {
  raise @core.RequestError::not_supported(
    "iOS drag-resize requests are not supported",
  )
}

///|
pub fn Window::show_window_menu(
  self : Window,
  _position : @dpi.Position,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_skip_taskbar(self : Window, _skip : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::current_monitor(___self : Window) -> @core.MonitorHandle? {
  Some(default_monitor())
}

///|
pub fn Window::available_monitors(
  ___self : Window,
) -> Array[@core.MonitorHandle] {
  [default_monitor()]
}

///|
pub fn Window::primary_monitor(___self : Window) -> @core.MonitorHandle? {
  Some(default_monitor())
}

///|
pub fn Window::scale_factor(self : Window) -> Double {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.scale_factor
    None => platform_default_scale()
  }
}

///|
pub fn Window::window_handle(self : Window) -> UInt64 {
  self.surface_handle_
}

///|
pub fn Window::display_handle(___self : Window) -> UInt64 {
  0UL
}

///|
pub fn Window::rwh_06_window_handle(self : Window) -> UInt64 {
  self.window_handle()
}

///|
pub fn Window::rwh_06_display_handle(self : Window) -> UInt64 {
  self.display_handle()
}

///|
/// UIView* pointer as UInt64 for embedding consumers.
pub fn Window::view_handle(self : Window) -> UInt64 {
  self.surface_handle_
}

///|
/// UIWindow* pointer as UInt64 when available.
pub fn Window::ui_window_handle(self : Window) -> UInt64 {
  self.surface_token_
}

///|
pub fn Window::bind_surface(
  self : Window,
  surface_handle : UInt64,
  surface_token : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Unit {
  self.surface_handle_ = surface_handle
  self.surface_token_ = surface_token
  inject_surface_metrics(
    self.id_,
    width,
    height,
    scale_factor,
    surface_handle,
    surface_token,
  )
}
