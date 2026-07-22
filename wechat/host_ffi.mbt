///|
/// WeChat Mini Program host FFI — wasm exports for the JS runtime.
/// These functions are called by the Mini Program's JavaScript code to
/// dispatch events, touch input, lifecycle events, and render frames.

///|
/// Dispatch a window event from the JS runtime.
pub fn wechat_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  // Event dispatch for Mini Program → MoUI
  // The actual dispatch is handled by the host runtime
}

///|
/// Dispatch a pointer/touch input event from the JS runtime.
pub fn wechat_dispatch_pointer_input(
  raw_id : Int,
  kind : Int,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int,
  modifiers : Int,
) -> Int {
  // Pointer input dispatch for Mini Program → MoUI
  // The actual dispatch is handled by the host runtime
  0
}

///|
/// Trigger a render frame from the JS runtime.
pub fn wechat_render_frame() -> Unit {
  // Render frame dispatch
  // The actual dispatch is handled by the host runtime
}

///|
/// Notify that a surface (canvas) was created.
pub fn wechat_surface_created(
  width : Double,
  height : Double,
  scale_factor : Double,
) -> Unit {
  // Surface created dispatch
  // The actual dispatch is handled by the host runtime
}

///|
/// Notify that a surface (canvas) was destroyed.
pub fn wechat_surface_destroyed() -> Unit {
  // Surface destroyed dispatch
  // The actual dispatch is handled by the host runtime
}

///|
/// Notify that the app has been shown (foreground).
pub fn wechat_app_show() -> Unit {
  // App show dispatch
  // The actual dispatch is handled by the host runtime
}

///|
/// Notify that the app has been hidden (background).
pub fn wechat_app_hide() -> Unit {
  // App hide dispatch
  // The actual dispatch is handled by the host runtime
}