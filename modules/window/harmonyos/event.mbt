///|
/// Inject a surface created/changed notification from moui_shell.
pub fn inject_surface_metrics(
  window_id : @core.WindowId,
  width : Int,
  height : Int,
  scale_factor : Double,
  surface_handle : UInt64,
  surface_token : UInt64,
) -> Unit {
  let raw_id = window_id.into_raw()
  app_state_update_surface(
    raw_id, width, height, scale_factor, surface_handle, surface_token,
  )
  let size = platform_nonzero_size(width, height)
  app_state_queue_window_event(window_id, SurfaceResized(size))
  if scale_factor > 0.0 {
    app_state_queue_window_event(
      window_id,
      ScaleFactorChanged(scale_factor, SurfaceSizeWriter(size)),
    )
  }
  app_state_request_redraw(raw_id)
}

///|
pub fn inject_pointer_moved(
  window_id : @core.WindowId,
  x : Double,
  y : Double,
) -> Unit {
  let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(x, y)
  app_state_queue_window_event(
    window_id,
    PointerMoved(None, position, true, Touch(@core.FingerId::from_raw(0), None)),
  )
}

///|
pub fn inject_pointer_button(
  window_id : @core.WindowId,
  pressed : Bool,
  x : Double,
  y : Double,
) -> Unit {
  let state = if pressed {
    @core.ElementState::Pressed
  } else {
    @core.ElementState::Released
  }
  let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(x, y)
  app_state_queue_window_event(
    window_id,
    PointerButton(
      None,
      state,
      position,
      true,
      Touch(@core.FingerId::from_raw(0), None),
    ),
  )
}

///|
pub fn inject_keyboard_text(window_id : @core.WindowId, text : String) -> Unit {
  app_state_queue_window_event(window_id, Ime(Commit(text)))
}

///|
pub fn inject_redraw(window_id : @core.WindowId) -> Unit {
  app_state_request_redraw(window_id.into_raw())
}

///|
pub fn inject_close_requested(window_id : @core.WindowId) -> Unit {
  app_state_queue_window_event(window_id, CloseRequested)
}

///|
pub fn inject_focus(window_id : @core.WindowId, focused : Bool) -> Unit {
  app_state_queue_window_event(window_id, Focused(focused))
}
