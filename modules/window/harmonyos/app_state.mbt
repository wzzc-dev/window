///|
priv enum DeferredCallback {
  NewEvents(@core.StartCause)
  Resumed
  CanCreateSurfaces
  ProxyWakeUp
  WindowEvent(@core.WindowId, @core.WindowEvent)
  Suspended
  DestroySurfaces
  MemoryWarning
}

///|
priv struct WindowEntry {
  raw_id : Int32
  mut title : String
  mut visible : Bool
  mut resizable : Bool
  mut cursor : @core.Cursor
  mut fullscreen : @core.Fullscreen?
  mut scale_factor : Double
  mut width : Int32
  mut height : Int32
  mut surface_handle : UInt64
  mut surface_token : UInt64
}

///|
priv struct AppStateRuntime {
  mut next_window_id : Int32
  mut is_running : Bool
  mut exit_requested : Bool
  mut exit_code : Int32
  mut control_flow : @core.ControlFlow
  mut pending_redraw_window_ids : Array[Int32]
  mut window_entries : Array[WindowEntry]
  mut deferred_callbacks : Array[DeferredCallback]
  mut dispatch_callback : ((DeferredCallback) -> Unit)?
  mut saw_init : Bool
}

///|
fn AppStateRuntime::new() -> AppStateRuntime {
  {
    next_window_id: 1,
    is_running: false,
    exit_requested: false,
    exit_code: 0,
    control_flow: Wait,
    pending_redraw_window_ids: [],
    window_entries: [],
    deferred_callbacks: [],
    dispatch_callback: None,
    saw_init: false,
  }
}

///|
let app_state_runtime : Ref[AppStateRuntime] = Ref(AppStateRuntime::new())

///|
let event_loop_global_created : Ref[Bool] = Ref(false)

///|
fn app_state_reset_for_test() -> Unit {
  app_state_runtime.val = AppStateRuntime::new()
  event_loop_global_created.val = false
}

///|
fn app_state_next_window_id() -> Int32 {
  let id = app_state_runtime.val.next_window_id
  app_state_runtime.val.next_window_id = id + 1
  id
}

///|
fn app_state_register_window_entry(entry : WindowEntry) -> Unit {
  let next : Array[WindowEntry] = []
  let mut replaced = false
  for existing in app_state_runtime.val.window_entries {
    if existing.raw_id == entry.raw_id {
      next.push(entry)
      replaced = true
    } else {
      next.push(existing)
    }
  }
  if !replaced {
    next.push(entry)
  }
  app_state_runtime.val.window_entries = next
}

///|
fn app_state_unregister_window(raw_id : Int32) -> Unit {
  let next : Array[WindowEntry] = []
  for entry in app_state_runtime.val.window_entries {
    if entry.raw_id != raw_id {
      next.push(entry)
    }
  }
  app_state_runtime.val.window_entries = next
}

///|
fn app_state_window_index(raw_id : Int32) -> Int32? {
  app_state_runtime.val.window_entries.search_by(entry => entry.raw_id == raw_id)
}

///|
fn app_state_window_entry(raw_id : Int32) -> WindowEntry? {
  match app_state_window_index(raw_id) {
    Some(i) => Some(app_state_runtime.val.window_entries[i])
    None => None
  }
}

///|
fn app_state_set_running(running : Bool) -> Unit {
  app_state_runtime.val.is_running = running
}

///|
fn app_state_is_running() -> Bool {
  app_state_runtime.val.is_running
}

///|
fn app_state_request_exit(code : Int32) -> Unit {
  app_state_runtime.val.exit_requested = true
  app_state_runtime.val.exit_code = code
}

///|
fn app_state_exit_requested() -> Bool {
  app_state_runtime.val.exit_requested
}

///|
fn app_state_exit_code() -> Int32 {
  app_state_runtime.val.exit_code
}

///|
fn app_state_set_control_flow(control_flow : @core.ControlFlow) -> Unit {
  app_state_runtime.val.control_flow = control_flow
}

///|
fn app_state_control_flow() -> @core.ControlFlow {
  app_state_runtime.val.control_flow
}

///|
fn app_state_queue_callback(callback : DeferredCallback) -> Unit {
  app_state_runtime.val.deferred_callbacks.push(callback)
}

///|
fn app_state_queue_lifecycle(callback : DeferredCallback) -> Unit {
  app_state_queue_callback(callback)
}

///|
fn app_state_queue_proxy_wake_up() -> Unit {
  app_state_queue_callback(ProxyWakeUp)
}

///|
fn app_state_queue_window_event(
  window_id : @core.WindowId,
  event : @core.WindowEvent,
) -> Unit {
  // Coalesce consecutive pointer moves: a drag at touchpad/touch sampling
  // rate enqueues far more moves than frames, and dispatching each pays the
  // full pipeline (pre-dispatch rebuild + render), so the visible thumb/
  // content lags the pointer by whole gesture clusters. The latest position
  // is the only one a positional consumer observes; intermediate samples are
  // safe to drop. Non-move events (Down/Up/Cancel, wheel deltas) keep strict
  // ordering and are never replaced.
  match event {
    @core.WindowEvent::PointerMoved(_, position, is_primary, source) => {
      let callbacks = app_state_runtime.val.deferred_callbacks
      let mut index = callbacks.length() - 1
      while index >= 0 {
        match callbacks[index] {
          WindowEvent(id, @core.WindowEvent::PointerMoved(_, _, _, _)) if id == window_id => {
            callbacks[index] = WindowEvent(
              window_id,
              @core.WindowEvent::PointerMoved(
                None,
                position,
                is_primary,
                source,
              ),
            )
            return
          }
          _ => ()
        }
        // Stop at any non-move event to preserve ordering against it.
        match callbacks[index] {
          WindowEvent(_, @core.WindowEvent::PointerMoved(_, _, _, _)) => ()
          _ => break
        }
        index = index - 1
      }
    }
    @core.WindowEvent::MouseWheel(
      _,
      @core.MouseScrollDelta::PixelDelta(delta),
      phase,
    ) => {
      // Coalesce consecutive wheel events by summing their pixel deltas: a
      // scroll gesture streams deltas at touchpad rate, and each dispatched
      // wheel pays the full pipeline (pre-dispatch rebuild + render), which
      // starved rendering to one frame per gesture cluster. Scroll distance
      // is additive, so merging preserves the total offset. The older queued
      // cursor stays (the merged event consumes it); the newer one is
      // dropped. Deltas and non-move events are never reordered.
      let callbacks = app_state_runtime.val.deferred_callbacks
      let mut index = callbacks.length() - 1
      while index >= 0 {
        match callbacks[index] {
          WindowEvent(
            id,
            @core.WindowEvent::MouseWheel(
              _,
              @core.MouseScrollDelta::PixelDelta(last),
              _,
            ),
          ) if id == window_id => {
            callbacks[index] = WindowEvent(
              window_id,
              @core.WindowEvent::MouseWheel(
                None,
                @core.MouseScrollDelta::PixelDelta(
                  @dpi.PhysicalPositionF64(delta.x + last.x, delta.y + last.y),
                ),
                phase,
              ),
            )
            app_state_drop_newest_scroll_cursor()
            return
          }
          _ => ()
        }
        match callbacks[index] {
          WindowEvent(_, @core.WindowEvent::MouseWheel(_, _, _)) => ()
          _ => break
        }
        index = index - 1
      }
    }
    _ => ()
  }
  app_state_queue_callback(WindowEvent(window_id, event))
}

///|
fn app_state_request_redraw(raw_id : Int32) -> Unit {
  let found = app_state_runtime.val.pending_redraw_window_ids.search_by(id => {
    id == raw_id
  })
  if found is None {
    app_state_runtime.val.pending_redraw_window_ids.push(raw_id)
  }
}

///|
fn app_state_take_pending_redraws() -> Array[Int32] {
  let pending = app_state_runtime.val.pending_redraw_window_ids
  app_state_runtime.val.pending_redraw_window_ids = []
  app_state_last_taken_redraws.val = pending.length()
  pending
}

/// Temporary diagnostic for the drag-tracking investigation. Remove with the probe.
let app_state_last_taken_redraws : Ref[Int] = Ref(0)

///|
pub fn app_state_redraw_queue_probe() -> String {
  "pending=\{app_state_runtime.val.pending_redraw_window_ids.length()} taken=\{app_state_last_taken_redraws.val}"
}

///|
/// Drops the newest wheel cursor after two queued wheels merge into one, so
/// the merged event consumes the older cursor and the queue stays 1:1.
fn app_state_drop_newest_scroll_cursor() -> Unit {
  let queued = scroll_cursors.val
  let keep = queued.length() - 1
  if keep > 0 {
    let rest : Array[(Double, Double)] = []
    for i in 0..<keep {
      rest.push(queued[i])
    }
    scroll_cursors.val = rest
  }
}

///|
fn app_state_set_dispatch_callback(
  callback : ((DeferredCallback) -> Unit)?,
) -> Unit {
  app_state_runtime.val.dispatch_callback = callback
}

///|
fn app_state_dispatch_pending() -> Unit {
  let callbacks = app_state_runtime.val.deferred_callbacks
  app_state_runtime.val.deferred_callbacks = []
  match app_state_runtime.val.dispatch_callback {
    Some(dispatch) =>
      for callback in callbacks {
        dispatch(callback)
      }
    None => ()
  }
}

///|
fn app_state_create_window_entry(
  title : String,
  width : Int32,
  height : Int32,
  scale_factor : Double,
  surface_handle : UInt64,
  surface_token : UInt64,
) -> WindowEntry {
  let raw_id = app_state_next_window_id()
  let entry : WindowEntry = {
    raw_id,
    title,
    visible: true,
    resizable: true,
    cursor: Icon(Default),
    fullscreen: None,
    scale_factor,
    width,
    height,
    surface_handle,
    surface_token,
  }
  app_state_register_window_entry(entry)
  entry
}

///|
fn app_state_ensure_init_events() -> Unit {
  if !app_state_runtime.val.saw_init {
    app_state_runtime.val.saw_init = true
    app_state_queue_callback(NewEvents(Init))
  }
}
