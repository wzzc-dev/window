///|
fn available_monitors() -> Array[@core.MonitorHandle] {
  let scale = web_scale_factor()
  let size = @dpi.PhysicalSize::new(0, 0)
  [
    @core.MonitorHandle::new(
      (0 : Int).to_uint64(),
      Some("browser viewport"),
      @dpi.PhysicalPosition::new(0, 0),
      size,
      scale,
      None,
      [],
    ),
  ]
}

///|
fn primary_monitor() -> @core.MonitorHandle? {
  match available_monitors() {
    [monitor] => Some(monitor)
    _ => None
  }
}

///|
pub fn monitor_canvas(_handle : @core.MonitorHandle) -> String? {
  None
}
