///|
/// WeChat Mini Program window type.
/// Wraps a Mini Program Canvas element.

///|
pub(all) struct Window {
  pub id : @core.WindowId
  pub canvas_id : String
  mut logical_size : @dpi.Size
  pub scale_factor : Double
}

///|
pub fn Window::new(
  id~ : @core.WindowId,
  canvas_id~ : String,
  size~ : @dpi.Size,
  scale_factor? : Double = 1.0,
) -> Window {
  { id, canvas_id, logical_size: size, scale_factor }
}

///|
pub fn Window::set_size(self : Window, size : @dpi.Size) -> Unit {
  self.logical_size = size
}

///|
pub fn Window::logical_width(self : Window) -> Double {
  let logical = self.logical_size.to_logical(self.scale_factor)
  logical.width()
}

///|
pub fn Window::logical_height(self : Window) -> Double {
  let logical = self.logical_size.to_logical(self.scale_factor)
  logical.height()
}
