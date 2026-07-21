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

///|
extern "C" fn mbw_android_sleep_ms(ms : Int) -> Unit = "mbw_android_sleep_ms"

///|
fn sleep_ms(ms : Int) -> Unit {
  mbw_android_sleep_ms(ms)
}
