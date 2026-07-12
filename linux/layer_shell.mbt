///|
/// Layer surface stack for wlr-layer-shell protocol.
/// Maps 1:1 to `zwlr_layer_shell_v1_layer`:
///   Background = 0, Bottom = 1, Top = 2, Overlay = 3
pub(all) enum Layer {
  Background
  Bottom
  Top
  Overlay
}

///|
pub fn Layer::to_int(self : Layer) -> Int {
  match self {
    Background => 0
    Bottom => 1
    Top => 2
    Overlay => 3
  }
}

///|
/// Check if the wlr-layer-shell protocol is available on this compositor.
pub fn EventLoop::layer_shell_available(self : EventLoop) -> Bool {
  let _ = self
  true
}

///|
/// Check if the wlr-layer-shell protocol is available on this compositor.
pub fn ActiveEventLoop::layer_shell_available(self : ActiveEventLoop) -> Bool {
  let _ = self
  true
}

///|
/// Try to create a layer surface window. Returns None if layer-shell is unavailable.
pub fn EventLoop::try_create_layer_window(
  self : EventLoop,
  attributes : @core.WindowAttributes,
  linux_attributes : WindowAttributesLinux,
  output : @core.MonitorHandle?,
  layer : Layer,
  namespace_id : String,
) -> Window? raise @core.RequestError {
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
  let ns_bytes = text_bytes(namespace_id)
  let output_handle = match output {
    Some(h) => h.native_id()
    None => (0 : Int).to_uint64()
  }
  let handle = native_window_create_layer_window(
    self.context,
    raw_id,
    size.width,
    size.height,
    title_bytes,
    title_bytes.length(),
    app_id_bytes,
    app_id_bytes.length(),
    if linux_attributes.use_shm_placeholder() { 1 } else { 0 },
    output_handle,
    layer.to_int(),
    ns_bytes,
    ns_bytes.length(),
  )
  if handle == (0 : Int).to_uint64() {
    raise @core.RequestError::os(
      "Linux layer window creation returned a null handle (zwlr_layer_shell_v1 unavailable?)",
    )
  }
  app_state_register_window_entry({
    raw_id,
    handle,
    title,
    visible: attributes.visible(),
    resizable: attributes.resizable(),
    cursor: attributes.cursor(),
    fullscreen: attributes.fullscreen(),
    surface_size: size,
    scale_factor: 1.0,
  })
  if !native_window_wait_configured(handle, 2000) {
    native_window_destroy(handle)
    app_state_unregister_window(raw_id)
    raise @core.RequestError::os(
      "Linux layer window did not receive an initial Wayland configure event",
    )
  }
  native_window_set_visible(handle, attributes.visible())
  let window : Window = {
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
  Some(window)
}
