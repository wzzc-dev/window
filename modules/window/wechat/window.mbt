///|
/// WeChat Mini Program window type.
/// Wraps a Mini Program Canvas element.
///
/// WeChat Mini Programs run inside a sandboxed WebView environment.
/// Desktop window APIs (cursor grab, IME composition, custom cursors,
/// fullscreen transitions, multi-monitor, multi-window) are not available.
/// Each unsupported method adopts an explicit contract per
/// `window/docs/platform-gaps.md`: NotSupported, StateOnly, NoOp, or
/// Placeholder.

///|
pub(all) struct Window {
  id : @core.WindowId
  canvas_id : String
  mut logical_size : @dpi.Size
  scale_factor : Double
  priv mut cursor_visible_state : Bool
  priv mut cursor_hittest_state : Bool
  priv mut cursor_state : @core.Cursor
  priv mut decorated_state : Bool
  priv mut fullscreen_state : @core.Fullscreen?
  priv mut ime_allowed_state : Bool
  priv mut ime_hints_state : @core.ImeHint
  priv mut ime_purpose_state : @core.ImePurpose
  priv mut ime_surrounding_text_state : @core.ImeSurroundingText?
}

///|
pub fn Window::new(
  id~ : @core.WindowId,
  canvas_id~ : String,
  size~ : @dpi.Size,
  scale_factor? : Double = 1.0,
) -> Window {
  {
    id,
    canvas_id,
    logical_size: size,
    scale_factor,
    cursor_visible_state: true,
    cursor_hittest_state: true,
    cursor_state: @core.Cursor::Icon(@core.CursorIcon::Default),
    decorated_state: true,
    fullscreen_state: None,
    ime_allowed_state: false,
    ime_hints_state: @core.ImeHint::none(),
    ime_purpose_state: @core.ImePurpose::Normal,
    ime_surrounding_text_state: None,
  }
}

///|
pub fn Window::id(self : Window) -> @core.WindowId {
  self.id
}

///|
pub fn Window::set_size(self : Window, size : @dpi.Size) -> Unit {
  self.logical_size = size
}

///|
pub fn Window::logical_width(self : Window) -> Double {
  let logical = self.logical_size.to_logical(self.scale_factor)
  logical.width()
}

///|
pub fn Window::logical_height(self : Window) -> Double {
  let logical = self.logical_size.to_logical(self.scale_factor)
  logical.height()
}

///|
pub fn Window::inner_size(self : Window) -> @dpi.PhysicalSize {
  let logical = self.logical_size.to_logical(self.scale_factor)
  @dpi.PhysicalSize::PhysicalSize(
    (logical.width() * self.scale_factor).to_int(),
    (logical.height() * self.scale_factor).to_int(),
  )
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
pub fn Window::scale_factor(self : Window) -> Double {
  self.scale_factor
}

///|
pub fn Window::request_redraw(_self : Window) -> Unit {
  // Redraw is triggered by the JS runtime via wechat_render_frame()
}

///|
pub fn Window::pre_present_notify(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::request_inner_size(
  self : Window,
  size : @dpi.Size,
) -> @dpi.PhysicalSize? {
  let physical = size.to_physical(self.scale_factor)
  self.logical_size = size
  Some(physical)
}

///|
pub fn Window::request_surface_size(
  self : Window,
  size : @dpi.Size,
) -> @dpi.PhysicalSize? {
  self.request_inner_size(size)
}

// --- Cursor (StateOnly / NotSupported) ---

///|
pub fn Window::set_cursor_icon(
  self : Window,
  cursor : @core.CursorIcon,
) -> Unit {
  self.cursor_state = @core.Cursor::Icon(cursor)
}

///|
pub fn Window::set_cursor(self : Window, cursor : @core.Cursor) -> Unit {
  self.cursor_state = cursor
}

///|
pub fn Window::cursor(self : Window) -> @core.Cursor {
  self.cursor_state
}

///|
pub fn Window::set_cursor_visible(self : Window, visible : Bool) -> Unit {
  self.cursor_visible_state = visible
}

///|
pub fn Window::is_cursor_visible(self : Window) -> Bool {
  self.cursor_visible_state
}

///|
#warnings("-unused_error_type")
pub fn Window::set_cursor_hittest(
  self : Window,
  hittest : Bool,
) -> Unit raise @core.RequestError {
  self.cursor_hittest_state = hittest
}

///|
pub fn Window::is_cursor_hittest(self : Window) -> Bool {
  self.cursor_hittest_state
}

///|
pub fn Window::set_cursor_grab(
  self : Window,
  mode : @core.CursorGrabMode,
) -> Unit raise @core.RequestError {
  let _ = self
  match mode {
    @core.CursorGrabMode::None => ()
    _ =>
      raise @core.RequestError::not_supported(
        "WeChat Mini Program cursor grab only supports CursorGrabMode::None",
      )
  }
}

///|
pub fn Window::set_cursor_position(
  self : Window,
  _position : @dpi.Position,
) -> Unit raise @core.RequestError {
  let _ = self
  raise @core.RequestError::not_supported(
    "WeChat Mini Program cursor positioning is not supported",
  )
}

// --- IME (StateOnly) ---

///|
pub fn Window::set_ime_allowed(self : Window, allowed : Bool) -> Unit {
  self.ime_allowed_state = allowed
}

///|
pub fn Window::ime_allowed(self : Window) -> Bool {
  self.ime_allowed_state
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
pub fn Window::set_ime_hints(self : Window, hints : @core.ImeHint) -> Unit {
  self.ime_hints_state = hints
}

///|
pub fn Window::ime_hints(self : Window) -> @core.ImeHint {
  self.ime_hints_state
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
pub fn Window::set_ime_surrounding_text(
  self : Window,
  text : @core.ImeSurroundingText,
) -> Unit {
  self.ime_surrounding_text_state = Some(text)
}

///|
pub fn Window::ime_surrounding_text(self : Window) -> @core.ImeSurroundingText? {
  self.ime_surrounding_text_state
}

///|
pub fn Window::request_ime_update(self : Window) -> Unit {
  let _ = self
}

// --- Window State (NoOp) ---

///|
pub fn Window::set_title(self : Window, _title : String) -> Unit {
  let _ = self
}

///|
pub fn Window::title(_self : Window) -> String {
  "WeChat Mini Program"
}

///|
pub fn Window::set_visible(self : Window, _visible : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_visible(_self : Window) -> Bool? {
  Some(true)
}

///|
pub fn Window::set_resizable(self : Window, _resizable : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_resizable(_self : Window) -> Bool {
  true
}

///|
pub fn Window::set_decorations(self : Window, decorations : Bool) -> Unit {
  self.decorated_state = decorations
}

///|
pub fn Window::is_decorated(self : Window) -> Bool {
  self.decorated_state
}

///|
pub fn Window::set_minimized(self : Window, _minimized : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_minimized(_self : Window) -> Bool? {
  Some(false)
}

///|
pub fn Window::set_maximized(self : Window, _maximized : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_maximized(_self : Window) -> Bool {
  false
}

///|
pub fn Window::focus_window(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::has_focus(_self : Window) -> Bool {
  true
}

// --- Fullscreen (StateOnly / NoOp) ---

///|
pub fn Window::set_fullscreen(
  self : Window,
  fullscreen : @core.Fullscreen?,
) -> Unit {
  self.fullscreen_state = fullscreen
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
pub fn Window::set_simple_fullscreen(self : Window, _simple : Bool) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::simple_fullscreen(_self : Window) -> Bool {
  false
}

///|
pub fn Window::set_window_level(
  self : Window,
  _level : @core.WindowLevel,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_enabled_buttons(
  self : Window,
  _buttons : @core.WindowButtons,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_transparent(self : Window, _transparent : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::set_blur(self : Window, _blur : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::set_theme(self : Window, _theme : @core.Theme?) -> Unit {
  let _ = self
}

///|
pub fn Window::theme(_self : Window) -> @core.Theme? {
  None
}

///|
pub fn Window::set_content_protected(self : Window, _protected : Bool) -> Unit {
  let _ = self
}
