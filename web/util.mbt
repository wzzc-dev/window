///|
fn web_scale_factor() -> Double {
  let scale = web_device_pixel_ratio()
  if @dpi.validate_scale_factor(scale) {
    scale
  } else {
    1.0
  }
}

///|
fn web_nonzero_size(width : Int, height : Int) -> @dpi.PhysicalSize {
  PhysicalSize(
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
    Default => "default"
    ContextMenu => "context-menu"
    Help => "help"
    Progress => "progress"
    Wait => "wait"
    Cell => "cell"
    VerticalText => "vertical-text"
    Alias => "alias"
    Copy => "copy"
    NoDrop => "no-drop"
    Grab => "grab"
    Grabbing => "grabbing"
    EResize => "e-resize"
    NResize => "n-resize"
    NeResize => "ne-resize"
    NwResize => "nw-resize"
    SResize => "s-resize"
    SeResize => "se-resize"
    SwResize => "sw-resize"
    WResize => "w-resize"
    EwResize => "ew-resize"
    NsResize => "ns-resize"
    NeswResize => "nesw-resize"
    NwseResize => "nwse-resize"
    ColResize => "col-resize"
    RowResize => "row-resize"
    AllScroll => "all-scroll"
    ZoomIn => "zoom-in"
    ZoomOut => "zoom-out"
    Pointer => "pointer"
    Text => "text"
    Crosshair => "crosshair"
    Move => "move"
    NotAllowed => "not-allowed"
  }
}
