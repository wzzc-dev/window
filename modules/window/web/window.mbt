///|
pub struct Window {
  priv id_ : @core.WindowId
  priv canvas : WebCanvas
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
fn default_canvas_id(raw_id : Int) -> String {
  "moonbit-window-web-\{raw_id}"
}

///|
fn canvas_for_attributes(
  raw_id : Int,
  attributes : @core.WindowAttributes,
  web_attributes : WindowAttributesWeb,
) -> WebCanvas raise @core.RequestError {
  let scale = web_scale_factor()
  let size = match attributes.surface_size() {
    Some(size) => size.to_physical(scale)
    None => web_nonzero_size(800, 600)
  }
  let canvas = match web_attributes.canvas_id() {
    Some(id) => web_get_canvas_by_id(web_string_to_extern(id))
    None =>
      web_create_canvas(
        web_string_to_extern(default_canvas_id(raw_id)),
        size.width,
        size.height,
      )
  }
  if !web_canvas_is_valid(canvas) {
    raise @core.RequestError::os("Failed to create or find browser canvas")
  }
  web_set_canvas_size(canvas, size.width, size.height)
  canvas
}

///|
pub fn Window::new(
  event_loop : EventLoop,
  attributes : @core.WindowAttributes,
) -> Window raise @core.RequestError {
  Window::new_with_web_attributes(
    event_loop,
    attributes,
    WindowAttributesWeb::default(),
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
pub fn Window::new_with_web_attributes(
  _event_loop : EventLoop,
  attributes : @core.WindowAttributes,
  web_attributes : WindowAttributesWeb,
) -> Window raise @core.RequestError {
  let raw_id = app_state_next_window_id()
  let window_id = @core.WindowId::from_raw(raw_id)
  let canvas = canvas_for_attributes(raw_id, attributes, web_attributes)
  let scale = web_scale_factor()
  let title = attributes.title()
  if title != "" {
    web_set_document_title(web_string_to_extern(title))
  }
  web_set_canvas_visible(canvas, attributes.visible())
  web_install_canvas_events(raw_id, canvas)
  app_state_register_window_entry({
    raw_id,
    title,
    visible: attributes.visible(),
    resizable: attributes.resizable(),
    cursor: attributes.cursor(),
    fullscreen: attributes.fullscreen(),
    focused: true,
    scale_factor: scale,
  })
  {
    id_: window_id,
    canvas,
    cursor_visible_state: attributes.cursor_visible(),
    cursor_hittest_state: attributes.cursor_hittest(),
    transparent_state: attributes.transparent(),
    blur_state: attributes.blur(),
    decorated_state: attributes.decorations(),
    enabled_buttons_state: attributes.enabled_buttons(),
    window_level_state: attributes.window_level(),
    theme_state: attributes.theme(),
    ime_allowed_state: false,
    ime_capabilities_state: None,
    ime_hints_state: attributes.ime_hints(),
    ime_purpose_state: attributes.ime_purpose(),
    ime_surrounding_text_state: None,
  }
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
pub fn Window::canvas_id(self : Window) -> String {
  web_canvas_id(self.canvas)
}

///|
pub fn Window::drop(self : Window) -> Unit {
  web_remove_canvas_events(self.raw_id())
  app_state_unregister_window(self.raw_id())
}

///|
pub fn Window::set_title(self : Window, title : String) -> Unit {
  web_set_document_title(web_string_to_extern(title))
  app_state_set_window_title(self.raw_id(), title)
}

///|
pub fn Window::title(self : Window) -> String {
  app_state_window_title(self.raw_id())
}

///|
pub fn Window::set_visible(self : Window, visible : Bool) -> Unit {
  web_set_canvas_visible(self.canvas, visible)
  app_state_set_window_visible(self.raw_id(), visible)
}

///|
pub fn Window::is_visible(self : Window) -> Bool? {
  app_state_window_visible(self.raw_id())
}

///|
pub fn Window::inner_size(self : Window) -> @dpi.PhysicalSize {
  web_nonzero_size(
    web_canvas_width(self.canvas),
    web_canvas_height(self.canvas),
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
pub fn Window::inner_position(self : Window) -> @dpi.PhysicalPosition {
  @dpi.PhysicalPosition::PhysicalPosition(
    web_canvas_offset_left(self.canvas),
    web_canvas_offset_top(self.canvas),
  )
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
  position : @dpi.Position,
) -> Unit {
  let physical = position.to_physical(self.scale_factor())
  app_state_set_window_position(self.raw_id(), physical)
}

///|
pub fn Window::request_inner_size(
  self : Window,
  size : @dpi.Size,
) -> @dpi.PhysicalSize? {
  let physical = size.to_physical(self.scale_factor())
  web_set_canvas_size(self.canvas, physical.width, physical.height)
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
  app_state_request_redraw(self.raw_id())
}

///|
pub fn Window::pre_present_notify(self : Window) -> Unit {
  let _ = self
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
pub fn Window::is_minimized(self : Window) -> Bool? {
  let _ = self
  None
}

///|
pub fn Window::set_maximized(self : Window, _maximized : Bool) -> Unit {
  let _ = self
}

///|
pub fn Window::is_maximized(self : Window) -> Bool {
  let _ = self
  false
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
  web_set_canvas_cursor(
    self.canvas,
    web_string_to_extern(web_cursor_name(cursor)),
  )
  app_state_set_window_cursor(self.raw_id(), @core.Cursor::Icon(cursor))
}

///|
pub fn Window::set_cursor(self : Window, cursor : @core.Cursor) -> Unit {
  match cursor {
    @core.Cursor::Icon(icon) =>
      web_set_canvas_cursor(
        self.canvas,
        web_string_to_extern(web_cursor_name(icon)),
      )
    @core.Cursor::Custom(_) => ()
  }
  app_state_set_window_cursor(self.raw_id(), cursor)
}

///|
pub fn Window::cursor(self : Window) -> @core.Cursor {
  app_state_window_cursor(self.raw_id())
}

///|
pub fn Window::set_cursor_visible(self : Window, visible : Bool) -> Unit {
  self.cursor_visible_state = visible
  if visible {
    match self.cursor() {
      @core.Cursor::Icon(icon) =>
        web_set_canvas_cursor(
          self.canvas,
          web_string_to_extern(web_cursor_name(icon)),
        )
      @core.Cursor::Custom(_) => ()
    }
  } else {
    web_set_canvas_cursor(self.canvas, web_string_to_extern("none"))
  }
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
        "Browser cursor grab only supports CursorGrabMode::None",
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
    "Browser cursor positioning is not supported",
  )
}

///|
pub fn Window::focus_window(self : Window) -> Unit {
  web_focus_canvas(self.raw_id())
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
  web_set_canvas_fullscreen(self.raw_id(), fullscreen is Some(_))
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
  self.ime_allowed_state = allowed
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
  }
  web_set_ime_allowed(self.raw_id(), allowed)
}

///|
pub fn Window::ime_allowed(self : Window) -> Bool {
  self.ime_allowed_state
}

///|
pub fn Window::set_ime_cursor_area(
  self : Window,
  position : @dpi.Position,
  size : @dpi.Size,
) -> Unit {
  let logical_position = position.to_logical(self.scale_factor())
  let logical_size = size.to_logical(self.scale_factor())
  web_set_ime_cursor_area(
    self.raw_id(),
    logical_position.x(),
    logical_position.y(),
    logical_size.width().max(1.0),
    logical_size.height().max(1.0),
  )
}

///|
pub fn Window::ime_cursor_area_position(self : Window) -> @dpi.PhysicalPosition {
  let _ = self
  @dpi.PhysicalPosition::PhysicalPosition(0, 0)
}

///|
pub fn Window::ime_cursor_area_size(self : Window) -> @dpi.PhysicalSize {
  let _ = self
  @dpi.PhysicalSize::PhysicalSize(0, 0)
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
    @core.ImeRequest::Enable(enable_request) => {
      if self.ime_allowed_state {
        raise @core.ImeRequestError::AlreadyEnabled
      }
      self.ime_allowed_state = true
      self.ime_capabilities_state = Some(enable_request.capabilities())
      self.apply_ime_request_data(enable_request.request_data())
      web_set_ime_allowed(self.raw_id(), true)
    }
    @core.ImeRequest::Update(request_data) => {
      if !self.ime_allowed_state {
        raise @core.ImeRequestError::NotEnabled
      }
      self.apply_ime_request_data(request_data)
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
  match text {
    Some(surrounding_text) =>
      web_set_ime_surrounding_text(
        self.raw_id(),
        web_string_to_extern(surrounding_text.text()),
        surrounding_text.cursor(),
        surrounding_text.anchor(),
      )
    None =>
      web_set_ime_surrounding_text(
        self.raw_id(),
        web_string_to_extern(""),
        0,
        0,
      )
  }
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
    None => theme_from_native(web_system_theme())
  }
}

///|
pub fn Window::drag_window(self : Window) -> Unit raise @core.RequestError {
  let _ = self
  raise @core.RequestError::not_supported(
    "Browser drag-window requests are not supported",
  )
}

///|
pub fn Window::drag_resize_window(
  self : Window,
  _direction : @core.ResizeDirection,
) -> Unit raise @core.RequestError {
  let _ = self
  raise @core.RequestError::not_supported(
    "Browser drag-resize requests are not supported",
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
pub fn Window::display_handle(self : Window) -> UInt64 {
  self.rwh_06_display_handle()
}

///|
pub fn Window::window_handle(self : Window) -> UInt64 {
  self.rwh_06_window_handle()
}

///|
pub fn Window::rwh_06_display_handle(self : Window) -> UInt64 {
  let _ = self
  (0 : Int).to_uint64()
}

///|
pub fn Window::rwh_06_window_handle(self : Window) -> UInt64 {
  let _ = self
  (0 : Int).to_uint64()
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
  let _ = self
  primary_monitor()
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
