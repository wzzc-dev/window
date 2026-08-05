///|
pub struct Window {
  priv id_ : @core.WindowId
  priv surface_handle_ : UInt64
  priv surface_token_ : UInt64
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
  priv mut ime_cursor_area_position_state : @dpi.PhysicalPosition
  priv mut ime_cursor_area_size_state : @dpi.PhysicalSize
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
  Window::new_with_android_attributes(
    event_loop,
    attributes,
    WindowAttributesAndroid::default(),
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
pub fn Window::new_with_android_attributes(
  _event_loop : EventLoop,
  attributes : @core.WindowAttributes,
  platform_attributes : WindowAttributesAndroid,
) -> Window raise @core.RequestError {
  if !host_surfaces_allowed() {
    raise @core.RequestError::not_supported(
      "Android create_window requires can_create_surfaces (host surface ready)",
    )
  }
  let (host_w, host_h, host_scale, host_handle, host_token) = host_default_window_metrics()
  let scale = if platform_attributes.scale_factor() > 0.0 &&
    platform_attributes.scale_factor() != 1.0 {
    platform_attributes.scale_factor()
  } else {
    host_scale
  }
  let size = match attributes.surface_size() {
    Some(size) => size.to_physical(scale)
    None => {
      let w = if platform_attributes.width() > 0 {
        platform_attributes.width()
      } else {
        host_w
      }
      let h = if platform_attributes.height() > 0 {
        platform_attributes.height()
      } else {
        host_h
      }
      platform_nonzero_size(w, h)
    }
  }
  let handle = if platform_attributes.surface_handle() != 0UL {
    platform_attributes.surface_handle()
  } else {
    host_handle
  }
  let token = if platform_attributes.surface_token() != 0UL {
    platform_attributes.surface_token()
  } else {
    host_token
  }
  let entry = app_state_create_window_entry(
    attributes.title(),
    size.width,
    size.height,
    scale,
    handle,
    token,
  )
  let window = {
    id_: @core.WindowId::from_raw(entry.raw_id),
    surface_handle_: handle,
    surface_token_: token,
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
    ime_cursor_area_position_state: PhysicalPosition(0, 0),
    ime_cursor_area_size_state: PhysicalSize(1, 1),
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
#borrow(pixels)
extern "C" fn mbw_android_window_present_rgba_pixels(
  window_handle : UInt64,
  width : Int,
  height : Int,
  stride_bytes : Int,
  pixels : Bytes,
  pixel_len : Int,
) -> Int = "mbw_android_window_present_rgba_pixels"

///|
extern "C" fn mbw_android_window_clear_color(
  window_handle : UInt64,
  width : Int,
  height : Int,
  r : Byte,
  g : Byte,
  b : Byte,
  a : Byte,
) -> Int = "mbw_android_window_clear_color"

///|
/// Soft present path for hosted smoke / CPU blit. Returns 0 on success.
pub fn Window::present_rgba_pixels(
  self : Window,
  width : Int,
  height : Int,
  stride_bytes : Int,
  pixels : Bytes,
) -> Int {
  let handle = self.native_window_handle()
  if handle == 0UL {
    return -10
  }
  mbw_android_window_present_rgba_pixels(
    handle,
    width,
    height,
    stride_bytes,
    pixels,
    pixels.length(),
  )
}

///|
/// Fill the native window with a solid RGBA color (M3 smoke helper).
pub fn Window::clear_color(
  self : Window,
  r : Byte,
  g : Byte,
  b : Byte,
  a : Byte,
) -> Int {
  let handle = self.native_window_handle()
  if handle == 0UL {
    return -10
  }
  let size = self.surface_size()
  mbw_android_window_clear_color(handle, size.width, size.height, r, g, b, a)
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
  position : @dpi.Position,
  size : @dpi.Size,
) -> Unit {
  let scale = self.scale_factor()
  self.ime_cursor_area_position_state = position.to_physical(scale)
  self.ime_cursor_area_size_state = size.to_physical(scale)
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
pub fn Window::request_ime_update(
  self : Window,
  request : @core.ImeRequest,
) -> Unit raise @core.ImeRequestError {
  match request {
    Enable(enable_request) =>
      match self.ime_capabilities_state {
        Some(_) => raise AlreadyEnabled
        None => {
          self.ime_capabilities_state = Some(enable_request.capabilities())
          self.ime_allowed_state = true
          self.apply_ime_request_data(enable_request.request_data())
        }
      }
    Update(request_data) =>
      match self.ime_capabilities_state {
        Some(_) => self.apply_ime_request_data(request_data)
        None => raise NotEnabled
      }
    Disable => {
      self.ime_allowed_state = false
      self.ime_capabilities_state = None
    }
  }
}

///|
fn Window::apply_ime_request_data(
  self : Window,
  request_data : @core.ImeRequestData,
) -> Unit {
  match request_data.hint_and_purpose() {
    Some((hint, purpose)) => {
      self.ime_hints_state = hint
      self.ime_purpose_state = purpose
    }
    None => ()
  }
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
    "Android cursor positioning is not supported",
  )
}

///|
pub fn Window::set_cursor_hittest(self : Window, hittest : Bool) -> Unit {
  self.cursor_hittest_state = hittest
}

///|
pub fn Window::drag_window(___self : Window) -> Unit raise @core.RequestError {
  raise @core.RequestError::not_supported(
    "Android drag-window requests are not supported",
  )
}

///|
pub fn Window::drag_resize_window(
  __self : Window,
  _direction : @core.ResizeDirection,
) -> Unit raise @core.RequestError {
  raise @core.RequestError::not_supported(
    "Android drag-resize requests are not supported",
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
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.surface_handle
    None => self.surface_handle_
  }
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
/// ANativeWindow* pointer as UInt64 for JNI/embedding consumers.
pub fn Window::native_window_handle(self : Window) -> UInt64 {
  self.window_handle()
}

///|
/// JNI-side Surface identity (optional opaque token).
pub fn Window::surface_token(self : Window) -> UInt64 {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.surface_token
    None => self.surface_token_
  }
}

///|
pub fn Window::is_fullscreen(self : Window) -> Bool {
  match app_state_window_entry(self.raw_id()) {
    Some(entry) => entry.fullscreen is Some(_)
    None => false
  }
}

///|
pub fn Window::is_transparent(self : Window) -> Bool {
  self.transparent_state
}

///|
pub fn Window::set_transparent(self : Window, transparent : Bool) -> Unit {
  self.transparent_state = transparent
}

///|
pub fn Window::is_blurred(self : Window) -> Bool {
  self.blur_state
}

///|
pub fn Window::set_blur(self : Window, blur : Bool) -> Unit {
  self.blur_state = blur
}

///|
pub fn Window::is_cursor_visible(self : Window) -> Bool {
  self.cursor_visible_state
}

///|
pub fn Window::is_cursor_hittest(self : Window) -> Bool {
  self.cursor_hittest_state
}

///|
pub fn Window::has_shadow(___self : Window) -> Bool {
  false
}

///|
pub fn Window::set_has_shadow(self : Window, _shadow : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_document_edited(___self : Window) -> Bool {
  false
}

///|
pub fn Window::set_document_edited(self : Window, _edited : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_content_protected(___self : Window) -> Bool {
  false
}

///|
pub fn Window::is_borderless_game(___self : Window) -> Bool {
  false
}

///|
pub fn Window::set_borderless_game(self : Window, _enabled : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_occluded(___self : Window) -> Bool {
  false
}

///|
pub fn Window::min_inner_size(___self : Window) -> @dpi.PhysicalSize? {
  None
}

///|
pub fn Window::max_inner_size(___self : Window) -> @dpi.PhysicalSize? {
  None
}

///|
pub fn Window::min_surface_size(self : Window) -> @dpi.PhysicalSize? {
  self.min_inner_size()
}

///|
pub fn Window::max_surface_size(self : Window) -> @dpi.PhysicalSize? {
  self.max_inner_size()
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
pub fn Window::set_min_surface_size(self : Window, size : @dpi.Size?) -> Unit {
  self.set_min_inner_size(size)
}

///|
pub fn Window::set_max_surface_size(self : Window, size : @dpi.Size?) -> Unit {
  self.set_max_inner_size(size)
}

///|
pub fn Window::resize_increments(___self : Window) -> @dpi.PhysicalSize? {
  None
}

///|
pub fn Window::surface_resize_increments(self : Window) -> @dpi.PhysicalSize? {
  self.resize_increments()
}

///|
pub fn Window::set_resize_increments(
  self : Window,
  _increments : @dpi.Size?,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_surface_resize_increments(
  self : Window,
  increments : @dpi.Size?,
) -> Unit {
  self.set_resize_increments(increments)
}

///|
pub fn Window::window_level(self : Window) -> @core.WindowLevel {
  self.window_level_state
}

///|
pub fn Window::set_cursor_icon(self : Window, icon : @core.CursorIcon) -> Unit {
  self.set_cursor(Icon(icon))
}

///|
pub fn Window::safe_area(___self : Window) -> @dpi.PhysicalSize {
  PhysicalSize(0, 0)
}

///|
pub fn Window::set_prefers_status_bar_hidden(
  self : Window,
  _hidden : Bool,
) -> Unit {
  let _ = self
}

///|
pub fn Window::set_prefers_home_indicator_hidden(
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
pub fn Window::set_simple_fullscreen(
  _self : Window,
  _fullscreen : Bool,
) -> Unit raise @core.RequestError {
  raise @core.RequestError::not_supported(
    "simple fullscreen is not supported on this mobile backend",
  )
}

///|
pub fn Window::simple_fullscreen(___self : Window) -> Bool {
  false
}

///|
pub fn Window::set_unified_titlebar(self : Window, _enabled : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::unified_titlebar(___self : Window) -> Bool {
  false
}

///|
pub fn Window::set_tabbing_identifier(self : Window, _id : String) -> Unit {
  let _ = self
}

///|
pub fn Window::tabbing_identifier(___self : Window) -> String {
  ""
}

///|
pub fn Window::num_tabs(___self : Window) -> Int {
  1
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
pub fn Window::option_as_alt(___self : Window) -> @core.OptionAsAlt {
  None
}

///|
pub fn Window::set_option_as_alt(
  ___self : Window,
  _option : @core.OptionAsAlt,
) -> Unit {
  ()
}

///|
pub fn Window::reset_dead_keys(___self : Window) -> Unit {
  ()
}
