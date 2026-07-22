///|
fn monitor_context() -> UInt64 {
  app_state_context()
}

///|
fn monitor_count() -> Int {
  let context = monitor_context()
  if context == (0 : Int).to_uint64() {
    0
  } else {
    native_monitor_count(context)
  }
}

///|
fn linux_monitor_surface_size(width : Int, height : Int) -> @dpi.PhysicalSize {
  PhysicalSize(
    if width > 0 {
      width
    } else {
      1
    },
    if height > 0 {
      height
    } else {
      1
    },
  )
}

///|
fn linux_monitor_scale_factor(scale : Double) -> Double {
  if scale > 0.0 && !Double::is_nan(scale) && !Double::is_inf(scale) {
    scale
  } else {
    1.0
  }
}

///|
fn monitor_handle_at(index : Int) -> @core.MonitorHandle? {
  let context = monitor_context()
  if context == (0 : Int).to_uint64() {
    return None
  }
  let native_id = native_monitor_handle_at(context, index)
  if native_id == (0 : Int).to_uint64() {
    return None
  }
  let width = native_monitor_rect_width_at(context, index)
  let height = native_monitor_rect_height_at(context, index)
  let surface_size = linux_monitor_surface_size(width, height)
  let name = native_monitor_name_bytes_at(context, index).to_string()
  let scale = native_monitor_scale_factor_at(context, index)
  Some(
    MonitorHandle(
      native_id,
      Some(name),
      PhysicalPosition(
        native_monitor_rect_left_at(context, index),
        native_monitor_rect_top_at(context, index),
      ),
      surface_size,
      linux_monitor_scale_factor(scale),
      None,
      [],
    ),
  )
}

///|
fn monitor_from_native_id(native_id : UInt64) -> @core.MonitorHandle? {
  if native_id == (0 : Int).to_uint64() {
    return None
  }
  let count = monitor_count()
  for i in 0..<count {
    if native_monitor_handle_at(monitor_context(), i) == native_id {
      return monitor_handle_at(i)
    }
  }
  None
}

///|
fn available_monitors() -> Array[@core.MonitorHandle] {
  let monitors : Array[@core.MonitorHandle] = []
  let count = monitor_count()
  for i in 0..<count {
    match monitor_handle_at(i) {
      Some(monitor) => monitors.push(monitor)
      None => ()
    }
  }
  monitors
}

///|
fn primary_monitor() -> @core.MonitorHandle? {
  monitor_handle_at(0)
}

///|
fn current_monitor_for_window(window : UInt64) -> @core.MonitorHandle? {
  if monitor_context() == 0UL || window == 0UL {
    None
  } else {
    monitor_from_native_id(native_window_current_monitor_handle(window))
  }
}

///|
pub fn monitor_ns_screen(_handle : @core.MonitorHandle) -> UInt64? {
  None
}
