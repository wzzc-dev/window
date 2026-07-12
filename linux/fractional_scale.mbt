///|
/// Check if fractional scale protocol is available for this window.
pub fn Window::fractional_scale_available(self : Window) -> Bool {
  native_window_fractional_scale_available(self.handle) != 0
}

///|
/// Get the preferred fractional scale (in 120ths, e.g. 120 = 1.0x, 180 = 1.5x).
/// Returns 0 if fractional scale is unavailable.
pub fn Window::fractional_scale_preferred(self : Window) -> Int {
  native_window_fractional_scale_preferred(self.handle)
}

///|
/// Get the fractional scale factor as a double (e.g. 1.0, 1.5, 2.0).
/// Returns 1.0 if fractional scale is unavailable.
pub fn Window::fractional_scale_factor(self : Window) -> Double {
  let raw = self.fractional_scale_preferred()
  if raw > 0 {
    raw.to_double() / 120.0
  } else {
    1.0
  }
}
