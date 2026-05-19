///|
fn linux_nonzero_size(width : Int, height : Int) -> @dpi.PhysicalSize {
  @dpi.PhysicalSize::PhysicalSize(
    if width <= 0 {
      1
    } else {
      width
    },
    if height <= 0 {
      1
    } else {
      height
    },
  )
}

///|
fn theme_from_native(theme : Int) -> @core.Theme? {
  match theme {
    1 => Some(@core.Theme::Dark)
    0 => Some(@core.Theme::Light)
    _ => None
  }
}

///|
fn text_bytes(text : String) -> Bytes {
  @utf8.encode(text, bom=false)
}
