///|
/// Platform attributes for HarmonyOS hosted windows.
/// Surface metrics normally come from the host (`SurfaceInit`); optional
/// overrides remain for tests and advanced templates.
pub struct WindowAttributesHarmonyOS {
  priv mut surface_handle_ : UInt64
  priv mut surface_token_ : UInt64
  priv mut scale_factor_ : Double
  priv mut width_ : Int
  priv mut height_ : Int
}

///|
pub fn WindowAttributesHarmonyOS::default() -> WindowAttributesHarmonyOS {
  {
    surface_handle_: 0UL,
    surface_token_: 0UL,
    scale_factor_: 1.0,
    width_: 0,
    height_: 0,
  }
}

///|
pub fn WindowAttributesHarmonyOS::with_surface_handle(
  self : WindowAttributesHarmonyOS,
  handle : UInt64,
) -> WindowAttributesHarmonyOS {
  self.surface_handle_ = handle
  self
}

///|
pub fn WindowAttributesHarmonyOS::surface_handle(
  self : WindowAttributesHarmonyOS,
) -> UInt64 {
  self.surface_handle_
}

///|
pub fn WindowAttributesHarmonyOS::with_surface_token(
  self : WindowAttributesHarmonyOS,
  token : UInt64,
) -> WindowAttributesHarmonyOS {
  self.surface_token_ = token
  self
}

///|
pub fn WindowAttributesHarmonyOS::surface_token(
  self : WindowAttributesHarmonyOS,
) -> UInt64 {
  self.surface_token_
}

///|
pub fn WindowAttributesHarmonyOS::with_scale_factor(
  self : WindowAttributesHarmonyOS,
  scale : Double,
) -> WindowAttributesHarmonyOS {
  self.scale_factor_ = if scale > 0.0 { scale } else { 1.0 }
  self
}

///|
pub fn WindowAttributesHarmonyOS::scale_factor(
  self : WindowAttributesHarmonyOS,
) -> Double {
  self.scale_factor_
}

///|
pub fn WindowAttributesHarmonyOS::with_size(
  self : WindowAttributesHarmonyOS,
  width : Int,
  height : Int,
) -> WindowAttributesHarmonyOS {
  self.width_ = width
  self.height_ = height
  self
}

///|
pub fn WindowAttributesHarmonyOS::width(
  self : WindowAttributesHarmonyOS,
) -> Int {
  self.width_
}

///|
pub fn WindowAttributesHarmonyOS::height(
  self : WindowAttributesHarmonyOS,
) -> Int {
  self.height_
}
