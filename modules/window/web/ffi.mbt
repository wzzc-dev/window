///|
#external
type WebCanvas

///|
#external
priv type WebString

///|
extern "wasm" fn web_begin_create_string() -> WebString = "window_web" "begin_create_string"

///|
extern "wasm" fn web_string_append_char(handle : WebString, ch : Char) -> Unit = "window_web" "string_append_char"

///|
extern "wasm" fn web_finish_create_string(handle : WebString) -> WebString = "window_web" "finish_create_string"

///|
extern "wasm" fn web_begin_read_string(id : Int) -> WebString = "window_web" "begin_read_string"

///|
extern "wasm" fn web_string_read_char(handle : WebString) -> Int = "window_web" "string_read_char"

///|
extern "wasm" fn web_finish_read_string(handle : WebString) -> Unit = "window_web" "finish_read_string"

///|
fn web_string_to_extern(s : String) -> WebString {
  let handle = web_begin_create_string()
  for i in 0..<s.length() {
    web_string_append_char(handle, s.code_unit_at(i).unsafe_to_char())
  }
  web_finish_create_string(handle)
}

///|
fn web_string_from_id(id : Int) -> String {
  let buf = StringBuilder::new()
  let handle = web_begin_read_string(id)
  while true {
    let ch = web_string_read_char(handle)
    if ch == -1 {
      break
    }
    buf.write_char(ch.unsafe_to_char())
  }
  web_finish_read_string(handle)
  buf.to_string()
}

///|
extern "wasm" fn web_create_canvas(
  id : WebString,
  width : Int,
  height : Int,
) -> WebCanvas = "window_web" "create_canvas"

///|
extern "wasm" fn web_get_canvas_by_id(id : WebString) -> WebCanvas = "window_web" "get_canvas_by_id"

///|
extern "wasm" fn web_canvas_is_valid(canvas : WebCanvas) -> Bool = "window_web" "canvas_is_valid"

///|
extern "wasm" fn web_canvas_id(canvas : WebCanvas) -> String = "window_web" "canvas_id"

///|
extern "wasm" fn web_canvas_width(canvas : WebCanvas) -> Int = "window_web" "canvas_width"

///|
extern "wasm" fn web_canvas_height(canvas : WebCanvas) -> Int = "window_web" "canvas_height"

///|
extern "wasm" fn web_canvas_offset_left(canvas : WebCanvas) -> Int = "window_web" "canvas_offset_left"

///|
extern "wasm" fn web_canvas_offset_top(canvas : WebCanvas) -> Int = "window_web" "canvas_offset_top"

///|
extern "wasm" fn web_set_canvas_size(
  canvas : WebCanvas,
  width : Int,
  height : Int,
) -> Unit = "window_web" "set_canvas_size"

///|
extern "wasm" fn web_set_canvas_visible(
  canvas : WebCanvas,
  visible : Bool,
) -> Unit = "window_web" "set_canvas_visible"

///|
extern "wasm" fn web_set_canvas_cursor(
  canvas : WebCanvas,
  cursor : WebString,
) -> Unit = "window_web" "set_canvas_cursor"

///|
extern "wasm" fn web_set_document_title(title : WebString) -> Unit = "window_web" "set_document_title"

///|
extern "wasm" fn web_device_pixel_ratio() -> Double = "window_web" "device_pixel_ratio"

///|
extern "wasm" fn web_now_ms() -> Int64 = "window_web" "now_ms"

///|
extern "wasm" fn web_schedule_animation_frame() -> Unit = "window_web" "schedule_animation_frame"

///|
extern "wasm" fn web_schedule_timeout(delay_ms : Int) -> Unit = "window_web" "schedule_timeout"

///|
extern "wasm" fn web_schedule_microtask() -> Unit = "window_web" "schedule_microtask"

///|
extern "wasm" fn web_install_canvas_events(
  raw_id : Int,
  canvas : WebCanvas,
) -> Unit = "window_web" "install_canvas_events"

///|
extern "wasm" fn web_remove_canvas_events(raw_id : Int) -> Unit = "window_web" "remove_canvas_events"

///|
extern "wasm" fn web_set_ime_allowed(raw_id : Int, allowed : Bool) -> Unit = "window_web" "set_ime_allowed"

///|
extern "wasm" fn web_set_ime_cursor_area(
  raw_id : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "window_web" "set_ime_cursor_area"

///|
extern "wasm" fn web_set_ime_surrounding_text(
  raw_id : Int,
  text : WebString,
  cursor : Int,
  anchor : Int,
) -> Unit = "window_web" "set_ime_surrounding_text"

///|
extern "wasm" fn web_system_theme() -> Int = "window_web" "system_theme"

///|
extern "wasm" fn web_set_canvas_fullscreen(
  raw_id : Int,
  fullscreen : Bool,
) -> Unit = "window_web" "set_canvas_fullscreen"

///|
extern "wasm" fn web_focus_canvas(raw_id : Int) -> Unit = "window_web" "focus_canvas"
