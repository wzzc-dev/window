///|
extern "C" fn native_context_new() -> UInt64 = "mbw_native_context_new"

///|
/// Read the backend tag stored as the first field of a context/window struct.
/// Returns 0 for invalid handles, 1 for Wayland, and 2 for X11.
extern "C" fn native_backend_tag(ptr : UInt64) -> Int32 = "mbw_native_backend_tag"

///|
extern "C" fn native_context_destroy(context : UInt64) -> Unit = "mbw_native_context_destroy"

///|
extern "C" fn native_context_display_handle(context : UInt64) -> UInt64 = "mbw_native_context_display_handle"

///|
extern "C" fn native_context_wake_fd(context : UInt64) -> Int32 = "mbw_native_context_wake_fd"

///|
extern "C" fn native_context_system_theme(context : UInt64) -> Int32 = "mbw_native_context_system_theme"

///|
extern "C" fn native_context_clipboard_available(context : UInt64) -> Int32 = "mbw_native_context_clipboard_available"

///|
extern "C" fn native_context_clipboard_read_text(context : UInt64) -> Bytes = "mbw_native_context_clipboard_read_text"

///|
#borrow(text)
extern "C" fn native_context_clipboard_write_text(
  context : UInt64,
  text : Bytes,
  text_len : Int32,
) -> Int32 = "mbw_native_context_clipboard_write_text"

///|
extern "C" fn native_context_drag_drop_available(context : UInt64) -> Int32 = "mbw_native_context_drag_drop_available"

///|
extern "C" fn native_monitor_count(context : UInt64) -> Int32 = "mbw_native_monitor_count"

///|
extern "C" fn native_monitor_handle_at(
  context : UInt64,
  index : Int32,
) -> UInt64 = "mbw_native_monitor_handle_at"

///|
extern "C" fn native_monitor_rect_left_at(
  context : UInt64,
  index : Int32,
) -> Int32 = "mbw_native_monitor_rect_left_at"

///|
extern "C" fn native_monitor_rect_top_at(
  context : UInt64,
  index : Int32,
) -> Int32 = "mbw_native_monitor_rect_top_at"

///|
extern "C" fn native_monitor_rect_width_at(
  context : UInt64,
  index : Int32,
) -> Int32 = "mbw_native_monitor_rect_width_at"

///|
extern "C" fn native_monitor_rect_height_at(
  context : UInt64,
  index : Int32,
) -> Int32 = "mbw_native_monitor_rect_height_at"

///|
extern "C" fn native_monitor_scale_factor_at(
  context : UInt64,
  index : Int32,
) -> Double = "mbw_native_monitor_scale_factor_at"

///|
extern "C" fn native_monitor_name_bytes_at(
  context : UInt64,
  index : Int32,
) -> Bytes = "mbw_native_monitor_name_bytes_at"

///|
extern "C" fn native_now_ms() -> Int64 = "mbw_native_now_ms"

///|
extern "C" fn native_context_dispatch(
  context : UInt64,
  timeout_ms : Int32,
) -> Int32 = "mbw_native_context_dispatch"

///|
extern "C" fn native_context_wake(context : UInt64) -> Unit = "mbw_native_context_wake"

///|
#borrow(title, app_id)
extern "C" fn native_window_create(
  context : UInt64,
  raw_id : Int32,
  width : Int32,
  height : Int32,
  title : Bytes,
  title_len : Int32,
  app_id : Bytes,
  app_id_len : Int32,
  decorations : Bool,
  use_shm_placeholder : Bool,
) -> UInt64 = "mbw_native_window_create"

///|
extern "C" fn native_window_destroy(window : UInt64) -> Unit = "mbw_native_window_destroy"

///|
extern "C" fn native_window_wait_configured(
  window : UInt64,
  timeout_ms : Int32,
) -> Bool = "mbw_native_window_wait_configured"

///|
extern "C" fn native_window_surface_handle(window : UInt64) -> UInt64 = "mbw_native_window_surface_handle"

///|
extern "C" fn native_window_xdg_surface_handle(window : UInt64) -> UInt64 = "mbw_native_window_xdg_surface_handle"

///|
extern "C" fn native_window_xdg_toplevel_handle(window : UInt64) -> UInt64 = "mbw_native_window_xdg_toplevel_handle"

///|
extern "C" fn native_window_display_handle(window : UInt64) -> UInt64 = "mbw_native_window_display_handle"

///|
extern "C" fn native_window_current_monitor_handle(window : UInt64) -> UInt64 = "mbw_native_window_current_monitor_handle"

///|
extern "C" fn native_window_client_decorated(window : UInt64) -> Bool = "mbw_native_window_client_decorated"

///|
extern "C" fn native_window_take_drag_paths(window : UInt64) -> Bytes = "mbw_native_window_take_drag_paths"

///|
#borrow(title)
extern "C" fn native_window_set_title(
  window : UInt64,
  title : Bytes,
  title_len : Int32,
) -> Unit = "mbw_native_window_set_title"

///|
extern "C" fn native_window_set_decorations(
  window : UInt64,
  decorations : Bool,
) -> Unit = "mbw_native_window_set_decorations"

///|
extern "C" fn native_window_set_minimized(
  window : UInt64,
  minimized : Bool,
) -> Unit = "mbw_native_window_set_minimized"

///|
extern "C" fn native_window_set_maximized(
  window : UInt64,
  maximized : Bool,
) -> Unit = "mbw_native_window_set_maximized"

///|
extern "C" fn native_window_set_fullscreen(
  window : UInt64,
  fullscreen : Bool,
) -> Unit = "mbw_native_window_set_fullscreen"

///|
extern "C" fn native_window_set_visible(
  window : UInt64,
  visible : Bool,
) -> Unit = "mbw_native_window_set_visible"

///|
extern "C" fn native_window_request_surface_size(
  window : UInt64,
  width : Int32,
  height : Int32,
) -> Unit = "mbw_native_window_request_surface_size"

///|
extern "C" fn native_window_request_redraw(window : UInt64) -> Unit = "mbw_native_window_request_redraw"

///|
#borrow(pixels)
extern "C" fn native_window_present_rgba_pixels(
  window : UInt64,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
  pixels_len : Int32,
) -> Int32 = "mbw_native_window_present_rgba_pixels"

///|
#borrow(call_closure)
#owned(callback)
extern "C" fn native_install_window_event_callback(
  call_closure : FuncRef[
    (
      (Int32, Int32, Int32, Int32, Int32, Double) -> Unit,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Double,
    ) -> Unit,
  ],
  callback : (Int32, Int32, Int32, Int32, Int32, Double) -> Unit,
) -> Unit = "mbw_native_install_window_event_callback"

///|
#borrow(call_closure)
#owned(callback)
extern "C" fn native_install_input_event_callback(
  call_closure : FuncRef[
    (
      (Int32, Int32, Int32, Int32, Int32, Int64) -> Unit,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Int64,
    ) -> Unit,
  ],
  callback : (Int32, Int32, Int32, Int32, Int32, Int64) -> Unit,
) -> Unit = "mbw_native_install_input_event_callback"
