///|
/// Platform attributes for Android hosted windows.
/// Surface metrics normally come from the host (`SurfaceInit`); optional
/// overrides remain for tests and advanced templates.
pub struct WindowAttributesAndroid {
  priv mut surface_handle_ : UInt64
  priv mut surface_token_ : UInt64
  priv mut scale_factor_ : Double
  priv mut width_ : Int
  priv mut height_ : Int
}

///|
pub fn WindowAttributesAndroid::default() -> WindowAttributesAndroid {
  {
    surface_handle_: 0UL,
    surface_token_: 0UL,
    scale_factor_: 1.0,
    width_: 0,
    height_: 0,
  }
}

///|
pub fn WindowAttributesAndroid::with_surface_handle(
  self : WindowAttributesAndroid,
  handle : UInt64,
) -> WindowAttributesAndroid {
  self.surface_handle_ = handle
  self
}

///|
pub fn WindowAttributesAndroid::surface_handle(
  self : WindowAttributesAndroid,
) -> UInt64 {
  self.surface_handle_
}

///|
pub fn WindowAttributesAndroid::with_surface_token(
  self : WindowAttributesAndroid,
  token : UInt64,
) -> WindowAttributesAndroid {
  self.surface_token_ = token
  self
}

///|
pub fn WindowAttributesAndroid::surface_token(
  self : WindowAttributesAndroid,
) -> UInt64 {
  self.surface_token_
}

///|
pub fn WindowAttributesAndroid::with_scale_factor(
  self : WindowAttributesAndroid,
  scale : Double,
) -> WindowAttributesAndroid {
  self.scale_factor_ = if scale > 0.0 { scale } else { 1.0 }
  self
}

///|
pub fn WindowAttributesAndroid::scale_factor(
  self : WindowAttributesAndroid,
) -> Double {
  self.scale_factor_
}

///|
pub fn WindowAttributesAndroid::with_size(
  self : WindowAttributesAndroid,
  width : Int,
  height : Int,
) -> WindowAttributesAndroid {
  self.width_ = width
  self.height_ = height
  self
}

///|
pub fn WindowAttributesAndroid::width(self : WindowAttributesAndroid) -> Int {
  self.width_
}

///|
pub fn WindowAttributesAndroid::height(self : WindowAttributesAndroid) -> Int {
  self.height_
}
