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
let linux_event_drag_enter : Int = 30

///|
let linux_event_drag_move : Int = 31

///|
let linux_event_drag_drop : Int = 32

///|
let linux_event_drag_leave : Int = 33

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
fn linux_decode_drag_paths(raw_id : Int) -> Array[String] {
  match app_state_window_handle(raw_id) {
    Some(handle) =>
      if app_state_context() == 0UL {
        []
      } else {
        let text = @utf8.decode_lossy(
          native_window_take_drag_paths(handle)[:],
          ignore_bom=false,
        )
        let paths : Array[String] = []
        if text != "" {
          for path_view in text.split("\n") {
            let path = path_view.trim().to_owned()
            if path != "" {
              paths.push(path)
            }
          }
        }
        paths
      }
    None => []
  }
}

///|
fn linux_key_event(key_code : Int, pressed : Bool) -> @core.KeyEvent {
  let native_code = @core.NativeKeyCode::Xkb(key_code)
  let native_key = @core.NativeKey::Xkb(key_code)
  let physical_key = linux_physical_key(key_code, native_code)
  let modifiers = app_state_modifiers()
  let logical_key = linux_logical_key(key_code, native_key, modifiers)
  @core.KeyEvent::KeyEvent(
    physical_key,
    logical_key,
    linux_key_without_modifiers(key_code, native_key),
    @core.KeyLocation::Standard,
    linux_element_state(pressed),
    false,
    linux_key_text(key_code, modifiers, pressed),
    None,
  )
}

///|
fn linux_physical_key(
  key_code : Int,
  native_code : @core.NativeKeyCode,
) -> @core.PhysicalKey {
  match linux_key_code(key_code) {
    Some(code) => @core.PhysicalKey::from_key_code(code)
    None => @core.PhysicalKey::from_native_key_code(native_code)
  }
}

///|
fn linux_key_without_modifiers(
  key_code : Int,
  native_key : @core.NativeKey,
) -> @core.Key {
  match linux_key_code(key_code) {
    Some(code) =>
      match linux_named_key(code) {
        Some(named) => @core.Key::Named(named)
        None =>
          match linux_unshifted_text(code) {
            Some(text) => @core.Key::Character(text)
            None => @core.Key::from_native(native_key)
          }
      }
    None => @core.Key::from_native(native_key)
  }
}

///|
fn linux_logical_key(
  key_code : Int,
  native_key : @core.NativeKey,
  modifiers : @core.Modifiers,
) -> @core.Key {
  match linux_key_code(key_code) {
    Some(code) =>
      match linux_named_key(code) {
        Some(named) => @core.Key::Named(named)
        None =>
          match linux_text_for_key_code(code, modifiers) {
            Some(text) => @core.Key::Character(text)
            None => @core.Key::from_native(native_key)
          }
      }
    None => @core.Key::from_native(native_key)
  }
}

///|
fn linux_key_text(
  key_code : Int,
  modifiers : @core.Modifiers,
  pressed : Bool,
) -> String? {
  if !pressed ||
    modifiers.control_key() ||
    modifiers.alt_key() ||
    modifiers.meta_key() {
    None
  } else {
    match linux_key_code(key_code) {
      Some(code) => linux_text_for_key_code(code, modifiers)
      None => None
    }
  }
}

///|
fn linux_text_for_key_code(
  code : @core.KeyCode,
  modifiers : @core.Modifiers,
) -> String? {
  if modifiers.shift_key() {
    linux_shifted_text(code)
  } else {
    linux_unshifted_text(code)
  }
}

///|
fn linux_unshifted_text(code : @core.KeyCode) -> String? {
  match code {
    @core.KeyCode::KeyA => Some("a")
    @core.KeyCode::KeyB => Some("b")
    @core.KeyCode::KeyC => Some("c")
    @core.KeyCode::KeyD => Some("d")
    @core.KeyCode::KeyE => Some("e")
    @core.KeyCode::KeyF => Some("f")
    @core.KeyCode::KeyG => Some("g")
    @core.KeyCode::KeyH => Some("h")
    @core.KeyCode::KeyI => Some("i")
    @core.KeyCode::KeyJ => Some("j")
    @core.KeyCode::KeyK => Some("k")
    @core.KeyCode::KeyL => Some("l")
    @core.KeyCode::KeyM => Some("m")
    @core.KeyCode::KeyN => Some("n")
    @core.KeyCode::KeyO => Some("o")
    @core.KeyCode::KeyP => Some("p")
    @core.KeyCode::KeyQ => Some("q")
    @core.KeyCode::KeyR => Some("r")
    @core.KeyCode::KeyS => Some("s")
    @core.KeyCode::KeyT => Some("t")
    @core.KeyCode::KeyU => Some("u")
    @core.KeyCode::KeyV => Some("v")
    @core.KeyCode::KeyW => Some("w")
    @core.KeyCode::KeyX => Some("x")
    @core.KeyCode::KeyY => Some("y")
    @core.KeyCode::KeyZ => Some("z")
    @core.KeyCode::Digit1 => Some("1")
    @core.KeyCode::Digit2 => Some("2")
    @core.KeyCode::Digit3 => Some("3")
    @core.KeyCode::Digit4 => Some("4")
    @core.KeyCode::Digit5 => Some("5")
    @core.KeyCode::Digit6 => Some("6")
    @core.KeyCode::Digit7 => Some("7")
    @core.KeyCode::Digit8 => Some("8")
    @core.KeyCode::Digit9 => Some("9")
    @core.KeyCode::Digit0 => Some("0")
    @core.KeyCode::Space => Some(" ")
    @core.KeyCode::Minus => Some("-")
    @core.KeyCode::Equal => Some("=")
    @core.KeyCode::BracketLeft => Some("[")
    @core.KeyCode::BracketRight => Some("]")
    @core.KeyCode::Backslash => Some("\\")
    @core.KeyCode::Semicolon => Some(";")
    @core.KeyCode::Quote => Some("'")
    @core.KeyCode::Backquote => Some("`")
    @core.KeyCode::Comma => Some(",")
    @core.KeyCode::Period => Some(".")
    @core.KeyCode::Slash => Some("/")
    _ => None
  }
}

///|
fn linux_shifted_text(code : @core.KeyCode) -> String? {
  match code {
    @core.KeyCode::KeyA => Some("A")
    @core.KeyCode::KeyB => Some("B")
    @core.KeyCode::KeyC => Some("C")
    @core.KeyCode::KeyD => Some("D")
    @core.KeyCode::KeyE => Some("E")
    @core.KeyCode::KeyF => Some("F")
    @core.KeyCode::KeyG => Some("G")
    @core.KeyCode::KeyH => Some("H")
    @core.KeyCode::KeyI => Some("I")
    @core.KeyCode::KeyJ => Some("J")
    @core.KeyCode::KeyK => Some("K")
    @core.KeyCode::KeyL => Some("L")
    @core.KeyCode::KeyM => Some("M")
    @core.KeyCode::KeyN => Some("N")
    @core.KeyCode::KeyO => Some("O")
    @core.KeyCode::KeyP => Some("P")
    @core.KeyCode::KeyQ => Some("Q")
    @core.KeyCode::KeyR => Some("R")
    @core.KeyCode::KeyS => Some("S")
    @core.KeyCode::KeyT => Some("T")
    @core.KeyCode::KeyU => Some("U")
    @core.KeyCode::KeyV => Some("V")
    @core.KeyCode::KeyW => Some("W")
    @core.KeyCode::KeyX => Some("X")
    @core.KeyCode::KeyY => Some("Y")
    @core.KeyCode::KeyZ => Some("Z")
    @core.KeyCode::Digit1 => Some("!")
    @core.KeyCode::Digit2 => Some("@")
    @core.KeyCode::Digit3 => Some("#")
    @core.KeyCode::Digit4 => Some("$")
    @core.KeyCode::Digit5 => Some("%")
    @core.KeyCode::Digit6 => Some("^")
    @core.KeyCode::Digit7 => Some("&")
    @core.KeyCode::Digit8 => Some("*")
    @core.KeyCode::Digit9 => Some("(")
    @core.KeyCode::Digit0 => Some(")")
    @core.KeyCode::Space => Some(" ")
    @core.KeyCode::Minus => Some("_")
    @core.KeyCode::Equal => Some("+")
    @core.KeyCode::BracketLeft => Some("{")
    @core.KeyCode::BracketRight => Some("}")
    @core.KeyCode::Backslash => Some("|")
    @core.KeyCode::Semicolon => Some(":")
    @core.KeyCode::Quote => Some("\"")
    @core.KeyCode::Backquote => Some("~")
    @core.KeyCode::Comma => Some("<")
    @core.KeyCode::Period => Some(">")
    @core.KeyCode::Slash => Some("?")
    _ => None
  }
}

///|
fn linux_named_key(code : @core.KeyCode) -> @core.NamedKey? {
  match code {
    @core.KeyCode::Enter => Some(@core.NamedKey::Enter)
    @core.KeyCode::Tab => Some(@core.NamedKey::Tab)
    @core.KeyCode::Backspace => Some(@core.NamedKey::Backspace)
    @core.KeyCode::Escape => Some(@core.NamedKey::Escape)
    @core.KeyCode::ShiftLeft | @core.KeyCode::ShiftRight =>
      Some(@core.NamedKey::Shift)
    @core.KeyCode::ControlLeft | @core.KeyCode::ControlRight =>
      Some(@core.NamedKey::Control)
    @core.KeyCode::AltLeft | @core.KeyCode::AltRight =>
      Some(@core.NamedKey::Alt)
    @core.KeyCode::MetaLeft | @core.KeyCode::MetaRight =>
      Some(@core.NamedKey::Meta)
    @core.KeyCode::CapsLock => Some(@core.NamedKey::CapsLock)
    @core.KeyCode::Insert => Some(@core.NamedKey::Insert)
    @core.KeyCode::Delete => Some(@core.NamedKey::Delete)
    @core.KeyCode::Home => Some(@core.NamedKey::Home)
    @core.KeyCode::End => Some(@core.NamedKey::End)
    @core.KeyCode::PageUp => Some(@core.NamedKey::PageUp)
    @core.KeyCode::PageDown => Some(@core.NamedKey::PageDown)
    @core.KeyCode::ArrowLeft => Some(@core.NamedKey::ArrowLeft)
    @core.KeyCode::ArrowRight => Some(@core.NamedKey::ArrowRight)
    @core.KeyCode::ArrowUp => Some(@core.NamedKey::ArrowUp)
    @core.KeyCode::ArrowDown => Some(@core.NamedKey::ArrowDown)
    @core.KeyCode::F1 => Some(@core.NamedKey::F1)
    @core.KeyCode::F2 => Some(@core.NamedKey::F2)
    @core.KeyCode::F3 => Some(@core.NamedKey::F3)
    @core.KeyCode::F4 => Some(@core.NamedKey::F4)
    @core.KeyCode::F5 => Some(@core.NamedKey::F5)
    @core.KeyCode::F6 => Some(@core.NamedKey::F6)
    @core.KeyCode::F7 => Some(@core.NamedKey::F7)
    @core.KeyCode::F8 => Some(@core.NamedKey::F8)
    @core.KeyCode::F9 => Some(@core.NamedKey::F9)
    @core.KeyCode::F10 => Some(@core.NamedKey::F10)
    @core.KeyCode::F11 => Some(@core.NamedKey::F11)
    @core.KeyCode::F12 => Some(@core.NamedKey::F12)
    _ => None
  }
}

///|
fn linux_key_code(key_code : Int) -> @core.KeyCode? {
  match key_code {
    16 => Some(@core.KeyCode::KeyQ)
    17 => Some(@core.KeyCode::KeyW)
    18 => Some(@core.KeyCode::KeyE)
    19 => Some(@core.KeyCode::KeyR)
    20 => Some(@core.KeyCode::KeyT)
    21 => Some(@core.KeyCode::KeyY)
    22 => Some(@core.KeyCode::KeyU)
    23 => Some(@core.KeyCode::KeyI)
    24 => Some(@core.KeyCode::KeyO)
    25 => Some(@core.KeyCode::KeyP)
    26 => Some(@core.KeyCode::BracketLeft)
    27 => Some(@core.KeyCode::BracketRight)
    28 => Some(@core.KeyCode::Enter)
    30 => Some(@core.KeyCode::KeyA)
    31 => Some(@core.KeyCode::KeyS)
    32 => Some(@core.KeyCode::KeyD)
    33 => Some(@core.KeyCode::KeyF)
    34 => Some(@core.KeyCode::KeyG)
    35 => Some(@core.KeyCode::KeyH)
    36 => Some(@core.KeyCode::KeyJ)
    37 => Some(@core.KeyCode::KeyK)
    38 => Some(@core.KeyCode::KeyL)
    39 => Some(@core.KeyCode::Semicolon)
    40 => Some(@core.KeyCode::Quote)
    41 => Some(@core.KeyCode::Backquote)
    43 => Some(@core.KeyCode::Backslash)
    44 => Some(@core.KeyCode::KeyZ)
    45 => Some(@core.KeyCode::KeyX)
    46 => Some(@core.KeyCode::KeyC)
    47 => Some(@core.KeyCode::KeyV)
    48 => Some(@core.KeyCode::KeyB)
    49 => Some(@core.KeyCode::KeyN)
    50 => Some(@core.KeyCode::KeyM)
    51 => Some(@core.KeyCode::Comma)
    52 => Some(@core.KeyCode::Period)
    53 => Some(@core.KeyCode::Slash)
    57 => Some(@core.KeyCode::Space)
    2 => Some(@core.KeyCode::Digit1)
    3 => Some(@core.KeyCode::Digit2)
    4 => Some(@core.KeyCode::Digit3)
    5 => Some(@core.KeyCode::Digit4)
    6 => Some(@core.KeyCode::Digit5)
    7 => Some(@core.KeyCode::Digit6)
    8 => Some(@core.KeyCode::Digit7)
    9 => Some(@core.KeyCode::Digit8)
    10 => Some(@core.KeyCode::Digit9)
    11 => Some(@core.KeyCode::Digit0)
    12 => Some(@core.KeyCode::Minus)
    13 => Some(@core.KeyCode::Equal)
    14 => Some(@core.KeyCode::Backspace)
    15 => Some(@core.KeyCode::Tab)
    1 => Some(@core.KeyCode::Escape)
    42 => Some(@core.KeyCode::ShiftLeft)
    54 => Some(@core.KeyCode::ShiftRight)
    29 => Some(@core.KeyCode::ControlLeft)
    97 => Some(@core.KeyCode::ControlRight)
    56 => Some(@core.KeyCode::AltLeft)
    100 => Some(@core.KeyCode::AltRight)
    125 => Some(@core.KeyCode::MetaLeft)
    126 => Some(@core.KeyCode::MetaRight)
    58 => Some(@core.KeyCode::CapsLock)
    110 => Some(@core.KeyCode::Insert)
    111 => Some(@core.KeyCode::Delete)
    102 => Some(@core.KeyCode::Home)
    107 => Some(@core.KeyCode::End)
    104 => Some(@core.KeyCode::PageUp)
    109 => Some(@core.KeyCode::PageDown)
    105 => Some(@core.KeyCode::ArrowLeft)
    106 => Some(@core.KeyCode::ArrowRight)
    103 => Some(@core.KeyCode::ArrowUp)
    108 => Some(@core.KeyCode::ArrowDown)
    59 => Some(@core.KeyCode::F1)
    60 => Some(@core.KeyCode::F2)
    61 => Some(@core.KeyCode::F3)
    62 => Some(@core.KeyCode::F4)
    63 => Some(@core.KeyCode::F5)
    64 => Some(@core.KeyCode::F6)
    65 => Some(@core.KeyCode::F7)
    66 => Some(@core.KeyCode::F8)
    67 => Some(@core.KeyCode::F9)
    68 => Some(@core.KeyCode::F10)
    87 => Some(@core.KeyCode::F11)
    88 => Some(@core.KeyCode::F12)
    _ => None
  }
}

///|
fn linux_modifier_for_key_code(
  key_code : Int,
) -> (@core.ModifiersState, @core.ModifiersKeys)? {
  match key_code {
    42 => Some((@core.ModifiersState::shift(), @core.ModifiersKeys::lshift()))
    54 => Some((@core.ModifiersState::shift(), @core.ModifiersKeys::rshift()))
    29 =>
      Some((@core.ModifiersState::control(), @core.ModifiersKeys::lcontrol()))
    97 =>
      Some((@core.ModifiersState::control(), @core.ModifiersKeys::rcontrol()))
    56 => Some((@core.ModifiersState::alt(), @core.ModifiersKeys::lalt()))
    100 => Some((@core.ModifiersState::alt(), @core.ModifiersKeys::ralt()))
    125 => Some((@core.ModifiersState::meta(), @core.ModifiersKeys::lmeta()))
    126 => Some((@core.ModifiersState::meta(), @core.ModifiersKeys::rmeta()))
    _ => None
  }
}

///|
fn linux_modifier_family_still_pressed(
  pressed : @core.ModifiersKeys,
  state : @core.ModifiersState,
) -> Bool {
  if state.shift_key() {
    pressed.contains(@core.ModifiersKeys::lshift()) ||
    pressed.contains(@core.ModifiersKeys::rshift())
  } else if state.control_key() {
    pressed.contains(@core.ModifiersKeys::lcontrol()) ||
    pressed.contains(@core.ModifiersKeys::rcontrol())
  } else if state.alt_key() {
    pressed.contains(@core.ModifiersKeys::lalt()) ||
    pressed.contains(@core.ModifiersKeys::ralt())
  } else if state.meta_key() {
    pressed.contains(@core.ModifiersKeys::lmeta()) ||
    pressed.contains(@core.ModifiersKeys::rmeta())
  } else {
    false
  }
}

///|
fn linux_modifiers_without(
  state : @core.ModifiersState,
  remove : @core.ModifiersState,
) -> @core.ModifiersState {
  let mut next = @core.ModifiersState::none()
  if state.shift_key() && !remove.shift_key() {
    next = next.union(@core.ModifiersState::shift())
  }
  if state.control_key() && !remove.control_key() {
    next = next.union(@core.ModifiersState::control())
  }
  if state.alt_key() && !remove.alt_key() {
    next = next.union(@core.ModifiersState::alt())
  }
  if state.meta_key() && !remove.meta_key() {
    next = next.union(@core.ModifiersState::meta())
  }
  next
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
    k if k == linux_event_focus => {
      let focused = arg0 != 0
      app_state_set_window_focused(raw_id, focused)
      app_state_queue_window_event(raw_id, @core.WindowEvent::Focused(focused))
    }
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
    k if k == linux_event_key_down || k == linux_event_key_up => {
      match
        app_state_update_key_modifier(argi.to_int(), k == linux_event_key_down) {
        Some(modifiers) =>
          app_state_queue_window_event(
            raw_id,
            @core.WindowEvent::ModifiersChanged(modifiers),
          )
        None => ()
      }
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::KeyboardInput(
          None,
          linux_key_event(argi.to_int(), k == linux_event_key_down),
          false,
        ),
      )
    }
    k if k == linux_event_drag_enter => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        DragEntered(linux_decode_drag_paths(raw_id), position),
      )
    }
    k if k == linux_event_drag_move => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(raw_id, DragMoved(position))
    }
    k if k == linux_event_drag_drop => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        DragDropped(linux_decode_drag_paths(raw_id), position),
      )
    }
    k if k == linux_event_drag_leave =>
      app_state_queue_window_event(
        raw_id,
        DragLeft(
          Some(
            @dpi.PhysicalPositionF64::PhysicalPositionF64(
              arg0.to_double(),
              arg1.to_double(),
            ),
          ),
        ),
      )
    _ => ()
  }
}
