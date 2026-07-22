///|
/// Platform attributes for iOS hosted windows.
/// Surface metrics normally come from the host (`SurfaceInit`); optional
/// overrides remain for tests and advanced templates.
pub struct WindowAttributesiOS {
  priv mut surface_handle_ : UInt64
  priv mut surface_token_ : UInt64
  priv mut scale_factor_ : Double
  priv mut width_ : Int
  priv mut height_ : Int
}

///|
pub fn WindowAttributesiOS::default() -> WindowAttributesiOS {
  {
    surface_handle_: 0UL,
    surface_token_: 0UL,
    scale_factor_: 1.0,
    width_: 0,
    height_: 0,
  }
}

///|
pub fn WindowAttributesiOS::with_surface_handle(
  self : WindowAttributesiOS,
  handle : UInt64,
) -> WindowAttributesiOS {
  self.surface_handle_ = handle
  self
}

///|
pub fn WindowAttributesiOS::surface_handle(
  self : WindowAttributesiOS,
) -> UInt64 {
  self.surface_handle_
}

///|
pub fn WindowAttributesiOS::with_surface_token(
  self : WindowAttributesiOS,
  token : UInt64,
) -> WindowAttributesiOS {
  self.surface_token_ = token
  self
}

///|
pub fn WindowAttributesiOS::surface_token(self : WindowAttributesiOS) -> UInt64 {
  self.surface_token_
}

///|
pub fn WindowAttributesiOS::with_scale_factor(
  self : WindowAttributesiOS,
  scale : Double,
) -> WindowAttributesiOS {
  self.scale_factor_ = if scale > 0.0 { scale } else { 1.0 }
  self
}

///|
pub fn WindowAttributesiOS::scale_factor(self : WindowAttributesiOS) -> Double {
  self.scale_factor_
}

///|
pub fn WindowAttributesiOS::with_size(
  self : WindowAttributesiOS,
  width : Int,
  height : Int,
) -> WindowAttributesiOS {
  self.width_ = width
  self.height_ = height
  self
}

///|
pub fn WindowAttributesiOS::width(self : WindowAttributesiOS) -> Int {
  self.width_
}

///|
pub fn WindowAttributesiOS::height(self : WindowAttributesiOS) -> Int {
  self.height_
}
