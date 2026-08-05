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
  raw_id : Int
  mut title : String
  mut visible : Bool
  mut resizable : Bool
  mut cursor : @core.Cursor
  mut fullscreen : @core.Fullscreen?
  mut scale_factor : Double
  mut width : Int
  mut height : Int
  mut surface_handle : UInt64
  mut surface_token : UInt64
}

///|
priv struct AppStateRuntime {
  mut next_window_id : Int
  mut is_running : Bool
  mut exit_requested : Bool
  mut exit_code : Int
  mut control_flow : @core.ControlFlow
  mut pending_redraw_window_ids : Array[Int]
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
fn app_state_next_window_id() -> Int {
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
fn app_state_unregister_window(raw_id : Int) -> Unit {
  let next : Array[WindowEntry] = []
  for entry in app_state_runtime.val.window_entries {
    if entry.raw_id != raw_id {
      next.push(entry)
    }
  }
  app_state_runtime.val.window_entries = next
}

///|
fn app_state_window_index(raw_id : Int) -> Int? {
  app_state_runtime.val.window_entries.search_by(entry => entry.raw_id == raw_id)
}

///|
fn app_state_window_entry(raw_id : Int) -> WindowEntry? {
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
fn app_state_request_exit(code : Int) -> Unit {
  app_state_runtime.val.exit_requested = true
  app_state_runtime.val.exit_code = code
}

///|
fn app_state_exit_requested() -> Bool {
  app_state_runtime.val.exit_requested
}

///|
fn app_state_exit_code() -> Int {
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
  app_state_queue_callback(WindowEvent(window_id, event))
}

///|
fn app_state_request_redraw(raw_id : Int) -> Unit {
  let found = app_state_runtime.val.pending_redraw_window_ids.search_by(id => {
    id == raw_id
  })
  if found is None {
    app_state_runtime.val.pending_redraw_window_ids.push(raw_id)
  }
}

///|
fn app_state_take_pending_redraws() -> Array[Int] {
  let pending = app_state_runtime.val.pending_redraw_window_ids
  app_state_runtime.val.pending_redraw_window_ids = []
  pending
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
  width : Int,
  height : Int,
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
