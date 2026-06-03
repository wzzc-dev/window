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
    0x110 => Left
    0x111 => Right
    0x112 => Middle
    0x113 => Back
    0x114 => Forward
    _ => Left
  }
}

///|
fn linux_element_state(pressed : Bool) -> @core.ElementState {
  if pressed {
    Pressed
  } else {
    Released
  }
}

///|
fn linux_key_event(key_code : Int, pressed : Bool) -> @core.KeyEvent {
  let native_code = @core.NativeKeyCode::Xkb(key_code)
  let native_key = @core.NativeKey::Xkb(key_code)
  let physical_key = linux_physical_key(key_code, native_code)
  let modifiers = app_state_modifiers()
  let logical_key = linux_logical_key(key_code, native_key, modifiers)
  let location = linux_key_location(key_code)
  KeyEvent(
    physical_key,
    logical_key,
    linux_key_without_modifiers(key_code, native_key),
    location,
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
fn linux_key_location(key_code : Int) -> @core.KeyLocation {
  match linux_key_code(key_code) {
    Some(ShiftLeft | ControlLeft | AltLeft | MetaLeft) => Left
    Some(ShiftRight | ControlRight | AltRight | MetaRight) => Right
    Some(
      Numpad0
      | Numpad1
      | Numpad2
      | Numpad3
      | Numpad4
      | Numpad5
      | Numpad6
      | Numpad7
      | Numpad8
      | Numpad9
      | NumpadDecimal
      | NumpadMultiply
      | NumpadAdd
      | NumpadSubtract
      | NumpadDivide
      | NumpadEnter
    ) => Numpad
    _ => Standard
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
        Some(named) => Named(named)
        None =>
          match linux_unshifted_text(code) {
            Some(text) => Character(text)
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
        Some(named) => Named(named)
        None =>
          match linux_text_for_key_code(code, modifiers) {
            Some(text) => Character(text)
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
    KeyA => Some("a")
    KeyB => Some("b")
    KeyC => Some("c")
    KeyD => Some("d")
    KeyE => Some("e")
    KeyF => Some("f")
    KeyG => Some("g")
    KeyH => Some("h")
    KeyI => Some("i")
    KeyJ => Some("j")
    KeyK => Some("k")
    KeyL => Some("l")
    KeyM => Some("m")
    KeyN => Some("n")
    KeyO => Some("o")
    KeyP => Some("p")
    KeyQ => Some("q")
    KeyR => Some("r")
    KeyS => Some("s")
    KeyT => Some("t")
    KeyU => Some("u")
    KeyV => Some("v")
    KeyW => Some("w")
    KeyX => Some("x")
    KeyY => Some("y")
    KeyZ => Some("z")
    Digit1 => Some("1")
    Digit2 => Some("2")
    Digit3 => Some("3")
    Digit4 => Some("4")
    Digit5 => Some("5")
    Digit6 => Some("6")
    Digit7 => Some("7")
    Digit8 => Some("8")
    Digit9 => Some("9")
    Digit0 => Some("0")
    Space => Some(" ")
    Minus => Some("-")
    Equal => Some("=")
    BracketLeft => Some("[")
    BracketRight => Some("]")
    Backslash => Some("\\")
    Semicolon => Some(";")
    Quote => Some("'")
    Backquote => Some("`")
    Comma => Some(",")
    Period => Some(".")
    Slash => Some("/")
    _ => None
  }
}

///|
fn linux_shifted_text(code : @core.KeyCode) -> String? {
  match code {
    KeyA => Some("A")
    KeyB => Some("B")
    KeyC => Some("C")
    KeyD => Some("D")
    KeyE => Some("E")
    KeyF => Some("F")
    KeyG => Some("G")
    KeyH => Some("H")
    KeyI => Some("I")
    KeyJ => Some("J")
    KeyK => Some("K")
    KeyL => Some("L")
    KeyM => Some("M")
    KeyN => Some("N")
    KeyO => Some("O")
    KeyP => Some("P")
    KeyQ => Some("Q")
    KeyR => Some("R")
    KeyS => Some("S")
    KeyT => Some("T")
    KeyU => Some("U")
    KeyV => Some("V")
    KeyW => Some("W")
    KeyX => Some("X")
    KeyY => Some("Y")
    KeyZ => Some("Z")
    Digit1 => Some("!")
    Digit2 => Some("@")
    Digit3 => Some("#")
    Digit4 => Some("$")
    Digit5 => Some("%")
    Digit6 => Some("^")
    Digit7 => Some("&")
    Digit8 => Some("*")
    Digit9 => Some("(")
    Digit0 => Some(")")
    Space => Some(" ")
    Minus => Some("_")
    Equal => Some("+")
    BracketLeft => Some("{")
    BracketRight => Some("}")
    Backslash => Some("|")
    Semicolon => Some(":")
    Quote => Some("\"")
    Backquote => Some("~")
    Comma => Some("<")
    Period => Some(">")
    Slash => Some("?")
    _ => None
  }
}

///|
fn linux_named_key(code : @core.KeyCode) -> @core.NamedKey? {
  match code {
    Enter => Some(Enter)
    Tab => Some(Tab)
    Backspace => Some(Backspace)
    Escape => Some(Escape)
    ShiftLeft | ShiftRight => Some(Shift)
    ControlLeft | ControlRight => Some(Control)
    AltLeft | AltRight => Some(Alt)
    MetaLeft | MetaRight => Some(Meta)
    CapsLock => Some(CapsLock)
    Insert => Some(Insert)
    Delete => Some(Delete)
    Home => Some(Home)
    End => Some(End)
    PageUp => Some(PageUp)
    PageDown => Some(PageDown)
    ArrowLeft => Some(ArrowLeft)
    ArrowRight => Some(ArrowRight)
    ArrowUp => Some(ArrowUp)
    ArrowDown => Some(ArrowDown)
    F1 => Some(F1)
    F2 => Some(F2)
    F3 => Some(F3)
    F4 => Some(F4)
    F5 => Some(F5)
    F6 => Some(F6)
    F7 => Some(F7)
    F8 => Some(F8)
    F9 => Some(F9)
    F10 => Some(F10)
    F11 => Some(F11)
    F12 => Some(F12)
    _ => None
  }
}

///|
fn linux_key_code(key_code : Int) -> @core.KeyCode? {
  match key_code {
    16 => Some(KeyQ)
    17 => Some(KeyW)
    18 => Some(KeyE)
    19 => Some(KeyR)
    20 => Some(KeyT)
    21 => Some(KeyY)
    22 => Some(KeyU)
    23 => Some(KeyI)
    24 => Some(KeyO)
    25 => Some(KeyP)
    26 => Some(BracketLeft)
    27 => Some(BracketRight)
    28 => Some(Enter)
    30 => Some(KeyA)
    31 => Some(KeyS)
    32 => Some(KeyD)
    33 => Some(KeyF)
    34 => Some(KeyG)
    35 => Some(KeyH)
    36 => Some(KeyJ)
    37 => Some(KeyK)
    38 => Some(KeyL)
    39 => Some(Semicolon)
    40 => Some(Quote)
    41 => Some(Backquote)
    43 => Some(Backslash)
    44 => Some(KeyZ)
    45 => Some(KeyX)
    46 => Some(KeyC)
    47 => Some(KeyV)
    48 => Some(KeyB)
    49 => Some(KeyN)
    50 => Some(KeyM)
    51 => Some(Comma)
    52 => Some(Period)
    53 => Some(Slash)
    57 => Some(Space)
    2 => Some(Digit1)
    3 => Some(Digit2)
    4 => Some(Digit3)
    5 => Some(Digit4)
    6 => Some(Digit5)
    7 => Some(Digit6)
    8 => Some(Digit7)
    9 => Some(Digit8)
    10 => Some(Digit9)
    11 => Some(Digit0)
    12 => Some(Minus)
    13 => Some(Equal)
    14 => Some(Backspace)
    15 => Some(Tab)
    1 => Some(Escape)
    42 => Some(ShiftLeft)
    54 => Some(ShiftRight)
    29 => Some(ControlLeft)
    97 => Some(ControlRight)
    56 => Some(AltLeft)
    100 => Some(AltRight)
    125 => Some(MetaLeft)
    126 => Some(MetaRight)
    58 => Some(CapsLock)
    110 => Some(Insert)
    111 => Some(Delete)
    102 => Some(Home)
    107 => Some(End)
    104 => Some(PageUp)
    109 => Some(PageDown)
    105 => Some(ArrowLeft)
    106 => Some(ArrowRight)
    103 => Some(ArrowUp)
    108 => Some(ArrowDown)
    59 => Some(F1)
    60 => Some(F2)
    61 => Some(F3)
    62 => Some(F4)
    63 => Some(F5)
    64 => Some(F6)
    65 => Some(F7)
    66 => Some(F8)
    67 => Some(F9)
    68 => Some(F10)
    87 => Some(F11)
    88 => Some(F12)
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
  if kind == linux_event_proxy_wake {
    app_state_queue_proxy_wake_up()
    return
  }
  if raw_id <= 0 {
    return
  }
  if app_state_window_handle(raw_id) is None {
    return
  }
  match kind {
    k if k == linux_event_close =>
      app_state_queue_window_event(raw_id, CloseRequested)
    k if k == linux_event_destroyed => {
      match app_state_clear_modifiers() {
        Some(modifiers) =>
          app_state_queue_window_event(raw_id, ModifiersChanged(modifiers))
        None => ()
      }
      app_state_clear_window_runtime_state(raw_id)
      app_state_queue_window_event(raw_id, Destroyed)
    }
    k if k == linux_event_configure => {
      let size = linux_nonzero_size(arg0, arg1)
      app_state_set_window_surface_size(raw_id, size)
      app_state_queue_window_event(raw_id, SurfaceResized(size))
    }
    k if k == linux_event_redraw => app_state_queue_redraw(raw_id)
    k if k == linux_event_focus => {
      let focused = arg0 != 0
      app_state_queue_window_event(raw_id, Focused(focused))
      if !focused {
        match app_state_clear_modifiers() {
          Some(modifiers) =>
            app_state_queue_window_event(raw_id, ModifiersChanged(modifiers))
          None => ()
        }
      }
    }
    41 => {
      let theme = if argd > 0.0 { @core.Theme::Dark } else { Light }
      app_state_queue_window_event(raw_id, ThemeChanged(theme))
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
  if raw_id <= 0 || app_state_window_handle(raw_id) is None {
    return
  }
  match kind {
    k if k == linux_event_pointer_enter => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        PointerEntered(None, position, true, Mouse),
      )
    }
    k if k == linux_event_pointer_move => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        PointerMoved(None, position, true, Mouse),
      )
    }
    k if k == linux_event_pointer_leave =>
      app_state_queue_window_event(raw_id, PointerLeft(None, None, true, Mouse))
    k if k == linux_event_pointer_down || k == linux_event_pointer_up => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        PointerButton(
          None,
          linux_element_state(k == linux_event_pointer_down),
          position,
          true,
          Mouse(linux_mouse_button(arg2)),
        ),
      )
    }
    k if k == linux_event_wheel =>
      app_state_queue_window_event(
        raw_id,
        MouseWheel(
          None,
          PixelDelta(PhysicalPositionF64(arg0.to_double(), arg1.to_double())),
          Moved,
        ),
      )
    k if k == linux_event_key_down || k == linux_event_key_up => {
      match
        app_state_update_key_modifier(argi.to_int(), k == linux_event_key_down) {
        Some(modifiers) =>
          app_state_queue_window_event(raw_id, ModifiersChanged(modifiers))
        None => ()
      }
      app_state_queue_window_event(
        raw_id,
        KeyboardInput(
          None,
          linux_key_event(argi.to_int(), k == linux_event_key_down),
          false,
        ),
      )
    }
    _ => ()
  }
}
