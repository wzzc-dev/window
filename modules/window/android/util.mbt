///|
fn platform_nonzero_size(width : Int, height : Int) -> @dpi.PhysicalSize {
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
fn platform_default_scale() -> Double {
  1.0
}
