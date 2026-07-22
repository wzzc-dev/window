///|
priv enum DeferredCallback {
  NewEvents(@core.StartCause)
  CanCreateSurfaces
  ProxyWakeUp
  AboutToWait
  WindowEvent(@core.WindowId, @core.WindowEvent)
}

///|
priv struct WindowEntry {
  raw_id : Int
  handle : UInt64
  mut title : String
  mut visible : Bool
  mut resizable : Bool
  mut cursor : @core.Cursor
  mut fullscreen : @core.Fullscreen?
  mut focused : Bool
  mut surface_size : @dpi.PhysicalSize
  scale_factor : Double
}

///|
priv struct AppStateRuntime {
  mut next_window_id : Int
  mut is_running : Bool
  mut exit_requested : Bool
  mut exit_code : Int
  mut event_handler_in_use : Bool
  mut control_flow : @core.ControlFlow
  mut modifiers : @core.ModifiersState
  mut pressed_modifiers : @core.ModifiersKeys
  mut pending_redraw_window_ids : Array[Int]
  mut window_entries : Array[WindowEntry]
  mut deferred_callbacks : Array[DeferredCallback]
  mut dispatch_callback : ((DeferredCallback) -> Unit)?
  mut context : UInt64
}

///|
fn AppStateRuntime::new() -> AppStateRuntime {
  {
    next_window_id: 1,
    is_running: false,
    exit_requested: false,
    exit_code: 0,
    event_handler_in_use: false,
    control_flow: @core.ControlFlow::Wait,
    modifiers: @core.ModifiersState::none(),
    pressed_modifiers: @core.ModifiersKeys::none(),
    pending_redraw_window_ids: [],
    window_entries: [],
    deferred_callbacks: [],
    dispatch_callback: None,
    context: (0 : Int).to_uint64(),
  }
}

///|
let app_state_runtime : Ref[AppStateRuntime] = Ref(AppStateRuntime::new())

///|
let event_loop_global_created : Ref[Bool] = Ref(false)

///|
fn app_state_set_context(context : UInt64) -> Unit {
  app_state_runtime.val.context = context
}

///|
fn app_state_context() -> UInt64 {
  app_state_runtime.val.context
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
    Some(index) => Some(app_state_runtime.val.window_entries[index])
    None => None
  }
}

///|
fn app_state_window_handle(raw_id : Int) -> UInt64? {
  match app_state_window_entry(raw_id) {
    Some(entry) => Some(entry.handle)
    None => None
  }
}

///|
fn app_state_update_window_entry(
  raw_id : Int,
  update : (WindowEntry) -> WindowEntry,
) -> Unit {
  match app_state_window_index(raw_id) {
    Some(index) => {
      let entry = app_state_runtime.val.window_entries[index]
      app_state_runtime.val.window_entries[index] = update(entry)
    }
    None => ()
  }
}

///|
fn app_state_window_scale_factor(raw_id : Int) -> Double {
  match app_state_window_entry(raw_id) {
    Some(entry) => entry.scale_factor
    None => 1.0
  }
}

///|
fn app_state_set_window_surface_size(
  raw_id : Int,
  size : @dpi.PhysicalSize,
) -> Unit {
  app_state_update_window_entry(raw_id, entry => {
    entry.surface_size = size
    entry
  })
}

///|
fn app_state_window_surface_size(raw_id : Int) -> @dpi.PhysicalSize {
  match app_state_window_entry(raw_id) {
    Some(entry) => entry.surface_size
    None => @dpi.PhysicalSize::PhysicalSize(1, 1)
  }
}

///|
fn app_state_set_window_title(raw_id : Int, title : String) -> Unit {
  app_state_update_window_entry(raw_id, entry => {
    entry.title = title
    entry
  })
}

///|
fn app_state_window_title(raw_id : Int) -> String {
  match app_state_window_entry(raw_id) {
    Some(entry) => entry.title
    None => ""
  }
}

///|
fn app_state_set_window_visible(raw_id : Int, visible : Bool) -> Unit {
  app_state_update_window_entry(raw_id, entry => {
    entry.visible = visible
    entry
  })
}

///|
fn app_state_window_visible(raw_id : Int) -> Bool? {
  match app_state_window_entry(raw_id) {
    Some(entry) => Some(entry.visible)
    None => None
  }
}

///|
fn app_state_set_window_resizable(raw_id : Int, resizable : Bool) -> Unit {
  app_state_update_window_entry(raw_id, entry => {
    entry.resizable = resizable
    entry
  })
}

///|
fn app_state_window_resizable(raw_id : Int) -> Bool {
  match app_state_window_entry(raw_id) {
    Some(entry) => entry.resizable
    None => false
  }
}

///|
fn app_state_set_window_cursor(raw_id : Int, cursor : @core.Cursor) -> Unit {
  app_state_update_window_entry(raw_id, entry => {
    entry.cursor = cursor
    entry
  })
}

///|
fn app_state_window_cursor(raw_id : Int) -> @core.Cursor {
  match app_state_window_entry(raw_id) {
    Some(entry) => entry.cursor
    None => @core.Cursor::Icon(@core.CursorIcon::Default)
  }
}

///|
fn app_state_set_window_fullscreen(
  raw_id : Int,
  fullscreen : @core.Fullscreen?,
) -> Unit {
  app_state_update_window_entry(raw_id, entry => {
    entry.fullscreen = fullscreen
    entry
  })
}

///|
fn app_state_window_fullscreen(raw_id : Int) -> @core.Fullscreen? {
  match app_state_window_entry(raw_id) {
    Some(entry) => entry.fullscreen
    None => None
  }
}

///|
fn app_state_set_window_focused(raw_id : Int, focused : Bool) -> Unit {
  app_state_update_window_entry(raw_id, entry => {
    entry.focused = focused
    entry
  })
}

///|
fn app_state_window_focused(raw_id : Int) -> Bool {
  match app_state_window_entry(raw_id) {
    Some(entry) => entry.focused
    None => false
  }
}

///|
fn app_state_is_running() -> Bool {
  app_state_runtime.val.is_running
}

///|
fn app_state_set_running(running : Bool) -> Unit {
  app_state_runtime.val.is_running = running
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
fn app_state_set_exit(code : Int) -> Unit {
  app_state_runtime.val.exit_requested = true
  app_state_runtime.val.exit_code = code
  let context = app_state_context()
  if context != (0 : Int).to_uint64() {
    native_context_wake(context)
  }
}

///|
fn app_state_clear_exit() -> Unit {
  app_state_runtime.val.exit_requested = false
  app_state_runtime.val.exit_code = 0
}

///|
fn app_state_internal_exit() -> Unit {
  app_state_runtime.val.is_running = false
  app_state_runtime.val.deferred_callbacks = []
  app_state_runtime.val.pending_redraw_window_ids = []
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
fn app_state_modifiers() -> @core.Modifiers {
  @core.Modifiers::from_state(
    app_state_runtime.val.modifiers,
    app_state_runtime.val.pressed_modifiers,
  )
}

///|
fn app_state_update_key_modifier(
  key_code : Int,
  pressed : Bool,
) -> @core.Modifiers? {
  let before = app_state_modifiers()
  let mut state = app_state_runtime.val.modifiers
  let mut pressed_modifiers = app_state_runtime.val.pressed_modifiers
  match linux_modifier_for_key_code(key_code) {
    Some((modifier_state, modifier_key)) => {
      if pressed {
        state = state.union(modifier_state)
        pressed_modifiers = pressed_modifiers.union(modifier_key)
      } else {
        pressed_modifiers = pressed_modifiers.without(modifier_key)
        if !linux_modifier_family_still_pressed(
            pressed_modifiers, modifier_state,
          ) {
          state = linux_modifiers_without(state, modifier_state)
        }
      }
      app_state_runtime.val.modifiers = state
      app_state_runtime.val.pressed_modifiers = pressed_modifiers
      let next = app_state_modifiers()
      if next == before {
        None
      } else {
        Some(next)
      }
    }
    None => None
  }
}

///|
fn app_state_handler_ready() -> Bool {
  app_state_runtime.val.is_running &&
  !app_state_runtime.val.event_handler_in_use &&
  app_state_runtime.val.dispatch_callback is Some(_)
}

///|
fn[A : ApplicationHandler] app_state_set_dispatch_handler(
  app : A,
  active_loop : ActiveEventLoop,
) -> Unit {
  app_state_runtime.val.dispatch_callback = Some(fn(
    cb : DeferredCallback,
  ) -> Unit {
    app_state_dispatch_callback(app, active_loop, cb)
  })
}

///|
fn app_state_clear_dispatch_handler() -> Unit {
  app_state_runtime.val.dispatch_callback = None
}

///|
fn[A : ApplicationHandler] app_state_dispatch_callback(
  app : A,
  active_loop : ActiveEventLoop,
  callback : DeferredCallback,
) -> Unit {
  app_state_runtime.val.event_handler_in_use = true
  match callback {
    NewEvents(cause) => app.new_events(active_loop, cause)
    CanCreateSurfaces => app.can_create_surfaces(active_loop)
    ProxyWakeUp => app.proxy_wake_up(active_loop)
    AboutToWait => app.about_to_wait(active_loop)
    WindowEvent(window_id, event) =>
      app.window_event(active_loop, window_id, event)
  }
  app_state_runtime.val.event_handler_in_use = false
}

///|
fn app_state_queue_callback(callback : DeferredCallback) -> Unit {
  if app_state_handler_ready() &&
    !(app_state_runtime.val.event_handler_in_use &&
    callback is WindowEvent(_, @core.WindowEvent::RedrawRequested)) {
    match app_state_runtime.val.dispatch_callback {
      Some(dispatch) => dispatch(callback)
      None => app_state_runtime.val.deferred_callbacks.push(callback)
    }
  } else {
    app_state_runtime.val.deferred_callbacks.push(callback)
  }
}

///|
fn app_state_queue_window_event(
  raw_id : Int,
  event : @core.WindowEvent,
) -> Unit {
  app_state_queue_callback(WindowEvent(@core.WindowId::from_raw(raw_id), event))
}

///|
fn app_state_queue_proxy_wake_up() -> Unit {
  app_state_queue_callback(ProxyWakeUp)
}

///|
fn app_state_queue_redraw(raw_id : Int) -> Unit {
  let found = app_state_runtime.val.pending_redraw_window_ids.search_by(id => {
    id == raw_id
  })
  if found is None {
    app_state_runtime.val.pending_redraw_window_ids.push(raw_id)
  }
  match app_state_window_handle(raw_id) {
    Some(handle) => native_window_request_redraw(handle)
    None => ()
  }
}

///|
fn[A : ApplicationHandler] app_state_dispatch_deferred_callbacks(
  app : A,
  active_loop : ActiveEventLoop,
) -> Unit {
  let callbacks = app_state_runtime.val.deferred_callbacks
  app_state_runtime.val.deferred_callbacks = []
  for callback in callbacks {
    app_state_dispatch_callback(app, active_loop, callback)
  }
}

///|
fn[A : ApplicationHandler] app_state_dispatch_init_events(
  app : A,
  active_loop : ActiveEventLoop,
) -> Unit {
  app_state_set_dispatch_handler(app, active_loop)
  app_state_queue_callback(NewEvents(@core.StartCause::Init))
  app_state_queue_callback(CanCreateSurfaces)
  app_state_dispatch_deferred_callbacks(app, active_loop)
}

///|
fn[A : ApplicationHandler] app_state_dispatch_redraws(
  app : A,
  active_loop : ActiveEventLoop,
) -> Unit {
  let redraw_ids = app_state_runtime.val.pending_redraw_window_ids
  app_state_runtime.val.pending_redraw_window_ids = []
  for raw_id in redraw_ids {
    app_state_queue_window_event(raw_id, @core.WindowEvent::RedrawRequested)
  }
  app_state_dispatch_deferred_callbacks(app, active_loop)
}

///|
fn app_state_install_native_callbacks() -> Unit {
  native_install_window_event_callback(
    fn(callback, kind, raw_id, arg0, arg1, arg2, argd) {
      callback(kind, raw_id, arg0, arg1, arg2, argd)
    },
    native_callback_window_event,
  )
  native_install_input_event_callback(
    fn(callback, raw_id, kind, arg0, arg1, arg2, argi) {
      callback(raw_id, kind, arg0, arg1, arg2, argi)
    },
    native_callback_input_event,
  )
}

///|
fn native_callback_window_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  arg2 : Int,
  argd : Double,
) -> Unit {
  dispatch_native_window_event(kind, raw_id, arg0, arg1, arg2, argd)
}

///|
fn native_callback_input_event(
  raw_id : Int,
  kind : Int,
  arg0 : Int,
  arg1 : Int,
  arg2 : Int,
  argi : Int64,
) -> Unit {
  dispatch_native_input_event(raw_id, kind, arg0, arg1, arg2, argi)
}
