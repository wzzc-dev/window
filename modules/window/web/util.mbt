///|
fn web_normalize_scale_factor(scale : Double) -> Double {
  if @dpi.validate_scale_factor(scale) {
    scale
  } else {
    1.0
  }
}

///|
fn web_scale_factor() -> Double {
  web_normalize_scale_factor(web_device_pixel_ratio())
}

///|
fn web_nonzero_size(width : Int, height : Int) -> @dpi.PhysicalSize {
  @dpi.PhysicalSize::PhysicalSize(
    if width > 0 {
      width
    } else {
      800
    },
    if height > 0 {
      height
    } else {
      600
    },
  )
}

///|
fn web_cursor_name(icon : @core.CursorIcon) -> String {
  match icon {
    @core.CursorIcon::Default => "default"
    @core.CursorIcon::ContextMenu => "context-menu"
    @core.CursorIcon::Help => "help"
    @core.CursorIcon::Progress => "progress"
    @core.CursorIcon::Wait => "wait"
    @core.CursorIcon::Cell => "cell"
    @core.CursorIcon::VerticalText => "vertical-text"
    @core.CursorIcon::Alias => "alias"
    @core.CursorIcon::Copy => "copy"
    @core.CursorIcon::NoDrop => "no-drop"
    @core.CursorIcon::Grab => "grab"
    @core.CursorIcon::Grabbing => "grabbing"
    @core.CursorIcon::EResize => "e-resize"
    @core.CursorIcon::NResize => "n-resize"
    @core.CursorIcon::NeResize => "ne-resize"
    @core.CursorIcon::NwResize => "nw-resize"
    @core.CursorIcon::SResize => "s-resize"
    @core.CursorIcon::SeResize => "se-resize"
    @core.CursorIcon::SwResize => "sw-resize"
    @core.CursorIcon::WResize => "w-resize"
    @core.CursorIcon::EwResize => "ew-resize"
    @core.CursorIcon::NsResize => "ns-resize"
    @core.CursorIcon::NeswResize => "nesw-resize"
    @core.CursorIcon::NwseResize => "nwse-resize"
    @core.CursorIcon::ColResize => "col-resize"
    @core.CursorIcon::RowResize => "row-resize"
    @core.CursorIcon::AllScroll => "all-scroll"
    @core.CursorIcon::ZoomIn => "zoom-in"
    @core.CursorIcon::ZoomOut => "zoom-out"
    @core.CursorIcon::Pointer => "pointer"
    @core.CursorIcon::Text => "text"
    @core.CursorIcon::Crosshair => "crosshair"
    @core.CursorIcon::Move => "move"
    @core.CursorIcon::NotAllowed => "not-allowed"
  }
}
