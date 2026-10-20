///|
fn platform_nonzero_size(width : Int32, height : Int32) -> @dpi.PhysicalSize {
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
extern "C" fn mbw_harmonyos_sleep_ms(ms : Int32) -> Unit = "mbw_harmonyos_sleep_ms"

///|
fn sleep_ms(ms : Int32) -> Unit {
  mbw_harmonyos_sleep_ms(ms)
}
