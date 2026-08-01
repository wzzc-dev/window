///|
pub struct Window {
  priv id : @core.WindowId
  priv handle : UInt64
  priv mut cursor_visible_state : Bool
  priv mut cursor_hittest_state : Bool
  priv mut transparent_state : Bool
  priv mut blur_state : Bool
  priv mut decorated_state : Bool
  priv mut minimized_state : Bool
  priv mut maximized_state : Bool
  priv mut enabled_buttons_state : @core.WindowButtons
  priv mut window_level_state : @core.WindowLevel
  priv mut theme_state : @core.Theme?
  priv mut ime_capabilities_state : @core.ImeCapabilities?
  priv mut ime_hints_state : @core.ImeHint
  priv mut ime_purpose_state : @core.ImePurpose
  priv mut ime_surrounding_text_state : @core.ImeSurroundingText?
  priv mut ime_cursor_area_position_state : @dpi.PhysicalPosition
  priv mut ime_cursor_area_size_state : @dpi.PhysicalSize
}

///|
pub impl Eq for Window with fn equal(self, other) {
  self.id == other.id
}

///|
pub type WindowAttributesLinuxAlias = WindowAttributesLinux

///|
fn default_app_id() -> String {
  "Milky2018.window"
}

///|
fn window_size_from_attributes(
  attributes : @core.WindowAttributes,
) -> @dpi.PhysicalSize {
  match attributes.surface_size() {
    Some(size) => size.to_physical(1.0)
    None => linux_nonzero_size(800, 600)
  }
}

///|
pub fn Window::new(
  event_loop : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  Window::new_with_linux_attributes(
    event_loop,
    attributes,
    WindowAttributesLinux::default(),
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
pub fn Window::new_with_linux_attributes(
  event_loop : EventLoop,
  attributes : @core.WindowAttributes,
  linux_attributes : WindowAttributesLinux,
) -> Window raise @core.RequestError {
  let raw_id = app_state_next_window_id()
  let window_id = @core.WindowId::from_raw(raw_id)
  let size = window_size_from_attributes(attributes)
  let title = attributes.title()
  let app_id = match linux_attributes.app_id() {
    Some(id) => id
    None => default_app_id()
  }
  let title_bytes = text_bytes(title)
  let app_id_bytes = text_bytes(app_id)
  let handle = native_window_create(
    event_loop.context,
    raw_id,
    size.width,
    size.height,
    title_bytes,
    title_bytes.length(),
    app_id_bytes,
    app_id_bytes.length(),
    attributes.decorations(),
    linux_attributes.use_shm_placeholder(),
  )
  if handle == (0 : Int).to_uint64() {
    raise @core.RequestError::os("Linux window creation returned a null handle")
  }
  app_state_register_window_entry({
    raw_id,
    handle,
    title,
    visible: attributes.visible(),
    resizable: attributes.resizable(),
    cursor: attributes.cursor(),
    fullscreen: attributes.fullscreen(),
    focused: false,
    surface_size: size,
    scale_factor: 1.0,
  })
  if !native_window_wait_configured(handle, 2000) {
    native_window_destroy(handle)
    app_state_unregister_window(raw_id)
    raise @core.RequestError::os(
      "Linux window did not receive an initial Wayland configure event",
    )
  }
  native_window_set_visible(handle, attributes.visible())
  if attributes.maximized() {
    native_window_set_maximized(handle, true)
  }
  {
    id: window_id,
    handle,
    cursor_visible_state: attributes.cursor_visible(),
    cursor_hittest_state: attributes.cursor_hittest(),
    transparent_state: attributes.transparent(),
    blur_state: attributes.blur(),
    decorated_state: attributes.decorations(),
    minimized_state: false,
    maximized_state: attributes.maximized(),
    enabled_buttons_state: attributes.enabled_buttons(),
    window_level_state: attributes.window_level(),
    theme_state: attributes.theme(),
    ime_capabilities_state: None,
    ime_hints_state: attributes.ime_hints(),
    ime_purpose_state: attributes.ime_purpose(),
    ime_surrounding_text_state: None,
    ime_cursor_area_position_state: PhysicalPosition(0, 0),
    ime_cursor_area_size_state: PhysicalSize(1, 1),
  }
}

///|
fn Window::raw_id(self : Window) -> Int {
  self.id.into_raw()
}

///|
pub fn Window::id(self : Window) -> @core.WindowId {
  self.id
}

///|
pub fn Window::drop(self : Window) -> Unit {
  native_window_destroy(self.handle)
  app_state_unregister_window(self.raw_id())
}

///|
pub fn Window::set_title(self : Window, title : String) -> Unit {
  let bytes = text_bytes(title)
  native_window_set_title(self.handle, bytes, bytes.length())
  app_state_set_window_title(self.raw_id(), title)
}

///|
pub fn Window::title(self : Window) -> String {
  app_state_window_title(self.raw_id())
}

///|
pub fn Window::set_visible(self : Window, visible : Bool) -> Unit {
  native_window_set_visible(self.handle, visible)
  app_state_set_window_visible(self.raw_id(), visible)
}

///|
pub fn Window::is_visible(self : Window) -> Bool? {
  app_state_window_visible(self.raw_id())
}

///|
pub fn Window::inner_size(self : Window) -> @dpi.PhysicalSize {
  app_state_window_surface_size(self.raw_id())
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
pub fn Window::inner_position(self : Window) -> @dpi.PhysicalPosition {
  let _ = self
  @dpi.PhysicalPosition::PhysicalPosition(0, 0)
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
  let physical = size.to_physical(self.scale_factor())
  native_window_request_surface_size(
    self.handle,
    physical.width,
    physical.height,
  )
  app_state_set_window_surface_size(self.raw_id(), physical)
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
  app_state_queue_redraw(self.raw_id())
}

///|
pub fn Window::pre_present_notify(self : Window) -> Unit {
  let _ = self
}

///|
pub fn Window::present_rgba_pixels(
  self : Window,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
) -> Int {
  native_window_present_rgba_pixels(
    self.handle,
    width,
    height,
    row_bytes,
    pixels,
    pixels.length(),
  )
}

///|
pub fn Window::set_resizable(self : Window, resizable : Bool) -> Unit {
  app_state_set_window_resizable(self.raw_id(), resizable)
}

///|
pub fn Window::is_resizable(self : Window) -> Bool {
  app_state_window_resizable(self.raw_id())
}

///|
pub fn Window::set_decorations(self : Window, decorations : Bool) -> Unit {
  self.decorated_state = decorations
  native_window_set_decorations(self.handle, decorations)
}

///|
pub fn Window::is_decorated(self : Window) -> Bool {
  self.decorated_state
}

///|
pub fn Window::uses_client_decorations(self : Window) -> Bool {
  native_window_client_decorated(self.handle)
}

///|
pub fn Window::set_minimized(self : Window, minimized : Bool) -> Unit {
  self.minimized_state = minimized
  native_window_set_minimized(self.handle, minimized)
}

///|
pub fn Window::is_minimized(self : Window) -> Bool? {
  Some(self.minimized_state)
}

///|
pub fn Window::set_maximized(self : Window, maximized : Bool) -> Unit {
  self.maximized_state = maximized
  native_window_set_maximized(self.handle, maximized)
}

///|
pub fn Window::is_maximized(self : Window) -> Bool {
  self.maximized_state
}

///|
pub fn Window::scale_factor(self : Window) -> Double {
  app_state_window_scale_factor(self.raw_id())
}

///|
pub fn Window::set_cursor_icon(
  self : Window,
  cursor : @core.CursorIcon,
) -> Unit {
  app_state_set_window_cursor(self.raw_id(), @core.Cursor::Icon(cursor))
}

///|
pub fn Window::set_cursor(self : Window, cursor : @core.Cursor) -> Unit {
  app_state_set_window_cursor(self.raw_id(), cursor)
}

///|
pub fn Window::cursor(self : Window) -> @core.Cursor {
  app_state_window_cursor(self.raw_id())
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
        "Linux cursor grab only supports CursorGrabMode::None",
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
    "Linux cursor positioning is not supported yet",
  )
}

///|
pub fn Window::focus_window(self : Window) -> Unit {
  app_state_set_window_focused(self.raw_id(), true)
}

///|
pub fn Window::has_focus(self : Window) -> Bool {
  app_state_window_focused(self.raw_id())
}

///|
pub fn Window::set_fullscreen(
  self : Window,
  fullscreen : @core.Fullscreen?,
) -> Unit {
  app_state_set_window_fullscreen(self.raw_id(), fullscreen)
  native_window_set_fullscreen(self.handle, fullscreen is Some(_))
}

///|
pub fn Window::fullscreen(self : Window) -> @core.Fullscreen? {
  app_state_window_fullscreen(self.raw_id())
}

///|
pub fn Window::is_fullscreen(self : Window) -> Bool {
  self.fullscreen() is Some(_)
}

///|
pub fn Window::set_window_level(
  self : Window,
  level : @core.WindowLevel,
) -> Unit {
  self.window_level_state = level
}

///|
pub fn Window::window_level(self : Window) -> @core.WindowLevel {
  self.window_level_state
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
pub fn Window::set_content_protected(self : Window, _protected : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_content_protected(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::set_skip_taskbar(self : Window, _skip : Bool) -> Unit {
  let _ = self
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
    self.ime_cursor_area_position_state = PhysicalPosition(0, 0)
    self.ime_cursor_area_size_state = PhysicalSize(1, 1)
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
  self.ime_cursor_area_size_state = PhysicalSize(width, height)
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
          self.apply_ime_request_data(enable_request.request_data())
        }
      }
    Update(request_data) =>
      match self.ime_capabilities_state {
        Some(_) => self.apply_ime_request_data(request_data)
        None => raise NotEnabled
      }
    Disable => self.set_ime_allowed(false)
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
  match request_data.hint_and_purpose() {
    Some((hint, purpose)) => {
      self.ime_hints_state = hint
      self.ime_purpose_state = purpose
    }
    None => ()
  }
  match request_data.cursor_area() {
    Some((position, size)) => self.set_ime_cursor_area(position, size)
    None => ()
  }
  match request_data.surrounding_text() {
    Some(text) => self.set_ime_surrounding_text(Some(text))
    None => ()
  }
}

///|
pub fn Window::set_has_shadow(self : Window, _shadow : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::has_shadow(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::set_blur(self : Window, blur : Bool) -> Unit {
  self.blur_state = blur
}

///|
pub fn Window::is_blurred(self : Window) -> Bool {
  self.blur_state
}

///|
pub fn Window::set_transparent(self : Window, transparent : Bool) -> Unit {
  self.transparent_state = transparent
}

///|
pub fn Window::is_transparent(self : Window) -> Bool {
  self.transparent_state
}

///|
pub fn Window::set_theme(self : Window, theme : @core.Theme?) -> Unit {
  self.theme_state = theme
}

///|
pub fn Window::theme(self : Window) -> @core.Theme? {
  match self.theme_state {
    Some(theme) => Some(theme)
    None => theme_from_native(native_context_system_theme(app_state_context()))
  }
}

///|
pub fn clipboard_available() -> Bool {
  let context = app_state_context()
  context != 0UL && native_context_clipboard_available(context) != 0
}

///|
pub fn read_clipboard_text() -> String? {
  let context = app_state_context()
  if context == 0UL || native_context_clipboard_available(context) == 0 {
    None
  } else {
    let bytes = native_context_clipboard_read_text(context)
    if bytes.length() == 0 {
      None
    } else {
      Some(@utf8.decode_lossy(bytes[:], ignore_bom=false))
    }
  }
}

///|
pub fn write_clipboard_text(text : String) -> Bool {
  let context = app_state_context()
  if context == 0UL || native_context_clipboard_available(context) == 0 {
    false
  } else {
    let bytes = text_bytes(text)
    native_context_clipboard_write_text(context, bytes, bytes.length()) != 0
  }
}

///|
pub fn drag_drop_available() -> Bool {
  let context = app_state_context()
  context != 0UL && native_context_drag_drop_available(context) != 0
}

///|
pub fn Window::drag_window(self : Window) -> Unit raise @core.RequestError {
  let _ = self
  raise @core.RequestError::not_supported(
    "Linux drag-window requests are not supported yet",
  )
}

///|
pub fn Window::drag_resize_window(
  self : Window,
  _direction : @core.ResizeDirection,
) -> Unit raise @core.RequestError {
  let _ = self
  raise @core.RequestError::not_supported(
    "Linux drag-resize requests are not supported yet",
  )
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
/// Return the raw Wayland `wl_surface*` handle for this window.
pub fn Window::native_window_handle(self : Window) -> UInt64 {
  native_window_surface_handle(self.handle)
}

///|
/// Return the raw Wayland `wl_display*` handle for this window.
pub fn Window::native_display_handle(self : Window) -> UInt64 {
  native_window_display_handle(self.handle)
}

///|
pub fn Window::rwh_06_display_handle(self : Window) -> UInt64 {
  self.native_display_handle()
}

///|
pub fn Window::rwh_06_window_handle(self : Window) -> UInt64 {
  self.native_window_handle()
}

///|
fn Window::raw_display_handle(
  self : Window,
) -> @windowing.RawDisplayHandle raise @windowing.HandleError {
  Wayland(@windowing.WaylandDisplayHandle::new(self.native_display_handle()))
}

///|
fn Window::raw_window_handle(
  self : Window,
) -> @windowing.RawWindowHandle raise @windowing.HandleError {
  Wayland(@windowing.WaylandWindowHandle::new(self.native_window_handle()))
}

///|
pub impl @windowing.DisplayHandleProvider for Window with fn raw_display_handle(
  self,
) {
  self.raw_display_handle()
}

///|
pub impl @windowing.WindowHandleProvider for Window with fn raw_window_handle(
  self,
) {
  self.raw_window_handle()
}

///|
pub fn Window::display_handle(self : Window) -> @windowing.DisplayHandle {
  @windowing.DisplayHandle::from_provider(
    self as &@windowing.DisplayHandleProvider,
  )
}

///|
pub impl @windowing.HasDisplayHandle for Window with fn display_handle(self) {
  self.display_handle()
}

///|
pub fn Window::window_handle(self : Window) -> @windowing.WindowHandle {
  @windowing.WindowHandle::from_provider(
    self as &@windowing.WindowHandleProvider,
  )
}

///|
pub impl @windowing.HasWindowHandle for Window with fn window_handle(self) {
  self.window_handle()
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
pub fn Window::set_borderless_game(self : Window, _borderless : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::option_as_alt(self : Window) -> @core.OptionAsAlt {
  let _ = self
  @core.OptionAsAlt::None
}

///|
pub fn Window::set_option_as_alt(
  self : Window,
  _option_as_alt : @core.OptionAsAlt,
) -> Unit {
  let _ = self
}

///|
pub fn Window::unified_titlebar(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::set_unified_titlebar(self : Window, _unified : Bool) -> Unit {
  let _ = self
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
pub fn Window::set_document_edited(self : Window, _edited : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_document_edited(self : Window) -> Bool {
  let _ = self
  false
}

///|
pub fn Window::current_monitor(self : Window) -> @core.MonitorHandle? {
  match app_state_window_handle(self.raw_id()) {
    Some(handle) => current_monitor_for_window(handle)
    None => None
  }
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
