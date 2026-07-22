///|
extern "C" fn native_context_new() -> UInt64 = "mbw_wayland_context_new"

///|
extern "C" fn native_context_destroy(context : UInt64) -> Unit = "mbw_wayland_context_destroy"

///|
extern "C" fn native_context_display_handle(context : UInt64) -> UInt64 = "mbw_wayland_context_display_handle"

///|
extern "C" fn native_context_wake_fd(context : UInt64) -> Int = "mbw_wayland_context_wake_fd"

///|
extern "C" fn native_context_system_theme(context : UInt64) -> Int = "mbw_wayland_context_system_theme"

///|
extern "C" fn native_context_clipboard_available(context : UInt64) -> Int = "mbw_wayland_context_clipboard_available"

///|
extern "C" fn native_context_clipboard_read_text(context : UInt64) -> Bytes = "mbw_wayland_context_clipboard_read_text"

///|
#borrow(text)
extern "C" fn native_context_clipboard_write_text(
  context : UInt64,
  text : Bytes,
  text_len : Int,
) -> Int = "mbw_wayland_context_clipboard_write_text"

///|
extern "C" fn native_context_drag_drop_available(context : UInt64) -> Int = "mbw_wayland_context_drag_drop_available"

///|
extern "C" fn native_monitor_count(context : UInt64) -> Int = "mbw_wayland_monitor_count"

///|
extern "C" fn native_monitor_handle_at(context : UInt64, index : Int) -> UInt64 = "mbw_wayland_monitor_handle_at"

///|
extern "C" fn native_monitor_rect_left_at(context : UInt64, index : Int) -> Int = "mbw_wayland_monitor_rect_left_at"

///|
extern "C" fn native_monitor_rect_top_at(context : UInt64, index : Int) -> Int = "mbw_wayland_monitor_rect_top_at"

///|
extern "C" fn native_monitor_rect_width_at(
  context : UInt64,
  index : Int,
) -> Int = "mbw_wayland_monitor_rect_width_at"

///|
extern "C" fn native_monitor_rect_height_at(
  context : UInt64,
  index : Int,
) -> Int = "mbw_wayland_monitor_rect_height_at"

///|
extern "C" fn native_monitor_scale_factor_at(
  context : UInt64,
  index : Int,
) -> Double = "mbw_wayland_monitor_scale_factor_at"

///|
extern "C" fn native_monitor_name_bytes_at(
  context : UInt64,
  index : Int,
) -> Bytes = "mbw_wayland_monitor_name_bytes_at"

///|
extern "C" fn native_now_ms() -> Int64 = "mbw_wayland_now_ms"

///|
extern "C" fn native_context_dispatch(
  context : UInt64,
  timeout_ms : Int,
) -> Int = "mbw_wayland_context_dispatch"

///|
extern "C" fn native_context_wake(context : UInt64) -> Unit = "mbw_wayland_context_wake"

///|
#borrow(title, app_id)
extern "C" fn native_window_create(
  context : UInt64,
  raw_id : Int,
  width : Int,
  height : Int,
  title : Bytes,
  title_len : Int,
  app_id : Bytes,
  app_id_len : Int,
  decorations : Bool,
  use_shm_placeholder : Bool,
) -> UInt64 = "mbw_wayland_window_create"

///|
extern "C" fn native_window_destroy(window : UInt64) -> Unit = "mbw_wayland_window_destroy"

///|
extern "C" fn native_window_wait_configured(
  window : UInt64,
  timeout_ms : Int,
) -> Bool = "mbw_wayland_window_wait_configured"

///|
extern "C" fn native_window_surface_handle(window : UInt64) -> UInt64 = "mbw_wayland_window_surface_handle"

///|
extern "C" fn native_window_xdg_surface_handle(window : UInt64) -> UInt64 = "mbw_wayland_window_xdg_surface_handle"

///|
extern "C" fn native_window_xdg_toplevel_handle(window : UInt64) -> UInt64 = "mbw_wayland_window_xdg_toplevel_handle"

///|
extern "C" fn native_window_display_handle(window : UInt64) -> UInt64 = "mbw_wayland_window_display_handle"

///|
extern "C" fn native_window_current_monitor_handle(window : UInt64) -> UInt64 = "mbw_wayland_window_current_monitor_handle"

///|
extern "C" fn native_window_client_decorated(window : UInt64) -> Bool = "mbw_wayland_window_client_decorated"

///|
extern "C" fn native_window_take_drag_paths(window : UInt64) -> Bytes = "mbw_wayland_window_take_drag_paths"

///|
#borrow(title)
extern "C" fn native_window_set_title(
  window : UInt64,
  title : Bytes,
  title_len : Int,
) -> Unit = "mbw_wayland_window_set_title"

///|
extern "C" fn native_window_set_decorations(
  window : UInt64,
  decorations : Bool,
) -> Unit = "mbw_wayland_window_set_decorations"

///|
extern "C" fn native_window_set_minimized(
  window : UInt64,
  minimized : Bool,
) -> Unit = "mbw_wayland_window_set_minimized"

///|
extern "C" fn native_window_set_maximized(
  window : UInt64,
  maximized : Bool,
) -> Unit = "mbw_wayland_window_set_maximized"

///|
extern "C" fn native_window_set_fullscreen(
  window : UInt64,
  fullscreen : Bool,
) -> Unit = "mbw_wayland_window_set_fullscreen"

///|
extern "C" fn native_window_set_visible(
  window : UInt64,
  visible : Bool,
) -> Unit = "mbw_wayland_window_set_visible"

///|
extern "C" fn native_window_request_surface_size(
  window : UInt64,
  width : Int,
  height : Int,
) -> Unit = "mbw_wayland_window_request_surface_size"

///|
extern "C" fn native_window_request_redraw(window : UInt64) -> Unit = "mbw_wayland_window_request_redraw"

///|
#borrow(pixels)
extern "C" fn native_window_present_rgba_pixels(
  window : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "mbw_wayland_window_present_rgba_pixels"

///|
#borrow(call_closure)
#owned(callback)
extern "C" fn native_install_window_event_callback(
  call_closure : FuncRef[
    ((Int, Int, Int, Int, Int, Double) -> Unit, Int, Int, Int, Int, Int, Double) -> Unit,
  ],
  callback : (Int, Int, Int, Int, Int, Double) -> Unit,
) -> Unit = "mbw_wayland_install_window_event_callback"

///|
#borrow(call_closure)
#owned(callback)
extern "C" fn native_install_input_event_callback(
  call_closure : FuncRef[
    ((Int, Int, Int, Int, Int, Int64) -> Unit, Int, Int, Int, Int, Int, Int64) -> Unit,
  ],
  callback : (Int, Int, Int, Int, Int, Int64) -> Unit,
) -> Unit = "mbw_wayland_install_input_event_callback"
