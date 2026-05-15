///|
fn available_monitors() -> Array[@core.MonitorHandle] {
  []
}

///|
fn primary_monitor() -> @core.MonitorHandle? {
  None
}

///|
pub fn monitor_ns_screen(_handle : @core.MonitorHandle) -> UInt64? {
  None
}
