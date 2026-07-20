///|
pub fn monitor_ns_screen(_handle : @core.MonitorHandle) -> UInt64? {
  None
}

///|
fn default_monitor() -> @core.MonitorHandle {
  @core.MonitorHandle::MonitorHandle(
    1UL,
    Some("Primary"),
    PhysicalPosition(0, 0),
    PhysicalSize(1080, 2400),
    3.0,
    None,
    [],
  )
}
