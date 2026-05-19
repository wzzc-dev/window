///|
let linux_event_close : Int = 1

///|
let linux_event_destroyed : Int = 2

///|
let linux_event_configure : Int = 3

///|
let linux_event_redraw : Int = 5

///|
let linux_event_focus : Int = 6

///|
let linux_event_proxy_wake : Int = 7

///|
let linux_event_pointer_enter : Int = 10

///|
let linux_event_pointer_move : Int = 11

///|
let linux_event_pointer_leave : Int = 12

///|
let linux_event_pointer_down : Int = 13

///|
let linux_event_pointer_up : Int = 14

///|
let linux_event_wheel : Int = 15

///|
let linux_event_key_down : Int = 20

///|
let linux_event_key_up : Int = 21

///|
fn linux_mouse_button(button : Int) -> @core.MouseButton {
  match button {
    0x110 => @core.MouseButton::Left
    0x111 => @core.MouseButton::Right
    0x112 => @core.MouseButton::Middle
    0x113 => @core.MouseButton::Back
    0x114 => @core.MouseButton::Forward
    _ => @core.MouseButton::Left
  }
}

///|
fn linux_element_state(pressed : Bool) -> @core.ElementState {
  if pressed {
    @core.ElementState::Pressed
  } else {
    @core.ElementState::Released
  }
}

///|
fn linux_key_event(key_code : Int, pressed : Bool) -> @core.KeyEvent {
  let native_code = @core.NativeKeyCode::Xkb(key_code)
  let native_key = @core.NativeKey::Xkb(key_code)
  let physical_key = @core.PhysicalKey::from_native_key_code(native_code)
  let logical_key = @core.Key::from_native(native_key)
  @core.KeyEvent::KeyEvent(
    physical_key,
    logical_key,
    logical_key,
    @core.KeyLocation::Standard,
    linux_element_state(pressed),
    false,
    None,
    None,
  )
}

///|
fn dispatch_native_window_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  _arg2 : Int,
  argd : Double,
) -> Unit {
  match kind {
    k if k == linux_event_close =>
      app_state_queue_window_event(raw_id, @core.WindowEvent::CloseRequested)
    k if k == linux_event_destroyed =>
      app_state_queue_window_event(raw_id, @core.WindowEvent::Destroyed)
    k if k == linux_event_configure => {
      let size = linux_nonzero_size(arg0, arg1)
      app_state_set_window_surface_size(raw_id, size)
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::SurfaceResized(size),
      )
    }
    k if k == linux_event_redraw => app_state_queue_redraw(raw_id)
    k if k == linux_event_focus =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::Focused(arg0 != 0),
      )
    k if k == linux_event_proxy_wake => app_state_queue_proxy_wake_up()
    41 => {
      let theme = if argd > 0.0 {
        @core.Theme::Dark
      } else {
        @core.Theme::Light
      }
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::ThemeChanged(theme),
      )
    }
    _ => ()
  }
}

///|
fn dispatch_native_input_event(
  raw_id : Int,
  kind : Int,
  arg0 : Int,
  arg1 : Int,
  arg2 : Int,
  argi : Int64,
) -> Unit {
  match kind {
    k if k == linux_event_pointer_enter => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::PointerEntered(
          None,
          position,
          true,
          @core.PointerKind::Mouse,
        ),
      )
    }
    k if k == linux_event_pointer_move => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::PointerMoved(
          None,
          position,
          true,
          @core.PointerSource::Mouse,
        ),
      )
    }
    k if k == linux_event_pointer_leave =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::PointerLeft(
          None,
          None,
          true,
          @core.PointerKind::Mouse,
        ),
      )
    k if k == linux_event_pointer_down || k == linux_event_pointer_up => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::PointerButton(
          None,
          linux_element_state(k == linux_event_pointer_down),
          position,
          true,
          @core.ButtonSource::Mouse(linux_mouse_button(arg2)),
        ),
      )
    }
    k if k == linux_event_wheel =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::MouseWheel(
          None,
          @core.MouseScrollDelta::PixelDelta(
            @dpi.PhysicalPositionF64::PhysicalPositionF64(
              arg0.to_double(),
              arg1.to_double(),
            ),
          ),
          @core.TouchPhase::Moved,
        ),
      )
    k if k == linux_event_key_down || k == linux_event_key_up =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::KeyboardInput(
          None,
          linux_key_event(argi.to_int(), k == linux_event_key_down),
          false,
        ),
      )
    _ => ()
  }
}
