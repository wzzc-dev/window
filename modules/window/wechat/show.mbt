///|
/// Debug display helpers for WeChat Mini Program types.
pub fn show(window : Window) -> String {
  "Window(" +
  window.canvas_id +
  " " +
  window.logical_width().to_string() +
  "x" +
  window.logical_height().to_string() +
  " @" +
  window.scale_factor.to_string() +
  "x)"
}
