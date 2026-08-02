///|
/// WeChat Mini Program monitor/screen information.
pub(all) struct Monitor {
  size : @dpi.Size
  scale_factor : Double
}

///|
pub fn Monitor::primary() -> Monitor {
  {
    size: @dpi.Size::from_logical(@dpi.LogicalSize::LogicalSize(375.0, 812.0)),
    scale_factor: 2.0,
  }
}
