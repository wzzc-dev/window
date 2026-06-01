///|
fn dispatch_native_window_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  arg2 : Int,
  argd : Double,
) -> Unit {
  match kind {
    1 => app_state_queue_window_event(raw_id, CloseRequested)
    2 => app_state_queue_window_event(raw_id, Destroyed)
    3 =>
      if arg2 == size_minimized {
        ()
      } else {
        let width = arg0
        let height = arg1
        if width > 0 && height > 0 {
          app_state_queue_window_event(
            raw_id,
            SurfaceResized(PhysicalSize(width, height)),
          )
        }
      }
    4 => {
      let x = arg0
      let y = arg1
      app_state_queue_window_event(raw_id, Moved(PhysicalPosition(x, y)))
    }
    5 => app_state_queue_redraw(raw_id)
    6 => {
      let active = arg0
      let focused = active == 1 || active == 2
      app_state_queue_window_event(raw_id, Focused(focused))
    }
    40 => {
      let dpi_x = arg0
      let _dpi_y = arg1
      let scale_factor = argd
      let window_id = @core.WindowId::from_raw(raw_id)
      let new_size = @dpi.PhysicalSize::PhysicalSize(dpi_x * 8, dpi_x * 5)
      app_state_queue_callback(
        ScaleFactorChanged(
          window_id,
          scale_factor,
          new_size.width,
          new_size.height,
        ),
      )
    }
    41 => {
      let theme = if argd > 0.0 { @core.Theme::Dark } else { Light }
      app_state_queue_window_event(raw_id, ThemeChanged(theme))
    }
    _ => ()
  }
}

///|
fn decode_lparam_position(lparam : Int64) -> @dpi.PhysicalPositionF64 {
  let x = (lparam & 0xFFFF : Int64).to_int()
  let y = ((lparam >> 16) & 0xFFFF : Int64).to_int()
  PhysicalPositionF64(x.to_double(), y.to_double())
}

///|
fn decode_lparam_position_signed(lparam : Int64) -> @dpi.PhysicalPositionF64 {
  let x_raw = (lparam & 0xFFFF : Int64).to_int()
  let y_raw = ((lparam >> 16) & 0xFFFF : Int64).to_int()
  let x = if x_raw > 32767 { x_raw - 65536 } else { x_raw }
  let y = if y_raw > 32767 { y_raw - 65536 } else { y_raw }
  PhysicalPositionF64(x.to_double(), y.to_double())
}

///|
fn text_from_native_utf8_ptr(ptr : UInt64, len : Int) -> String {
  @utf8.decode_lossy(native_consume_utf8_text(ptr, len)[:], ignore_bom=false)
}

///|
let window_mouse_tracking : Ref[Array[Int]] = Ref([])

///|
fn is_mouse_tracking(raw_id : Int) -> Bool {
  window_mouse_tracking.val.search_by(id => id == raw_id) is Some(_)
}

///|
fn set_mouse_tracking(raw_id : Int, tracking : Bool) -> Unit {
  let next : Array[Int] = []
  let mut found = false
  for id in window_mouse_tracking.val {
    if id == raw_id {
      if tracking {
        next.push(id)
      }
      found = true
    } else {
      next.push(id)
    }
  }
  if !found && tracking {
    next.push(raw_id)
  }
  window_mouse_tracking.val = next
}

///|
fn dispatch_native_input_event(
  raw_id : Int,
  kind : Int,
  wparam : UInt64,
  lparam : Int64,
) -> Unit {
  match kind {
    10 => {
      let position = decode_lparam_position(lparam)
      if is_mouse_tracking(raw_id) == false {
        set_mouse_tracking(raw_id, true)
        ignore(
          native_track_mouse_event(
            match app_state_window_handle(raw_id) {
              Some(hwnd) => hwnd
              None => (0 : Int).to_uint64()
            },
            tme_leave,
          ),
        )
        app_state_queue_window_event(
          raw_id,
          PointerEntered(None, position, false, Mouse),
        )
      }
      app_state_queue_window_event(
        raw_id,
        PointerMoved(None, position, false, Mouse),
      )
    }
    11 => {
      set_mouse_tracking(raw_id, false)
      let position = decode_lparam_position_signed(lparam)
      app_state_queue_window_event(
        raw_id,
        PointerLeft(None, Some(position), false, Mouse),
      )
    }
    12 => {
      let position = decode_lparam_position(lparam)
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Pressed, position, false, Mouse(Left)),
      )
    }
    13 => {
      let position = decode_lparam_position(lparam)
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Released, position, false, Mouse(Left)),
      )
    }
    14 => {
      let position = decode_lparam_position(lparam)
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Pressed, position, false, Mouse(Right)),
      )
    }
    15 => {
      let position = decode_lparam_position(lparam)
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Released, position, false, Mouse(Right)),
      )
    }
    16 => {
      let position = decode_lparam_position(lparam)
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Pressed, position, false, Mouse(Middle)),
      )
    }
    17 => {
      let position = decode_lparam_position(lparam)
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Released, position, false, Mouse(Middle)),
      )
    }
    18 => {
      let position = decode_lparam_position(lparam)
      let xbutton = ((wparam >> 16) & 0xFFFF : UInt64).to_int()
      let button = if xbutton == 1 { @core.MouseButton::Back } else { Forward }
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Pressed, position, false, Mouse(button)),
      )
    }
    19 => {
      let position = decode_lparam_position(lparam)
      let xbutton = ((wparam >> 16) & 0xFFFF : UInt64).to_int()
      let button = if xbutton == 1 { @core.MouseButton::Back } else { Forward }
      app_state_queue_window_event(
        raw_id,
        PointerButton(None, Released, position, false, Mouse(button)),
      )
    }
    20 => {
      let delta = ((wparam >> 16) & 0xFFFF : UInt64).to_int()
      let signed_delta = if delta > 32767 { delta - 65536 } else { delta }
      let lines = signed_delta.to_double() / wheel_delta.to_double()
      app_state_queue_window_event(
        raw_id,
        MouseWheel(None, LineDelta(0.0, lines), Moved),
      )
    }
    21 => {
      let delta = ((wparam >> 16) & 0xFFFF : UInt64).to_int()
      let signed_delta = if delta > 32767 { delta - 65536 } else { delta }
      let lines = signed_delta.to_double() / wheel_delta.to_double()
      app_state_queue_window_event(
        raw_id,
        MouseWheel(None, LineDelta(lines, 0.0), Moved),
      )
    }
    30 => {
      let vk_code = wparam.to_int()
      let physical_key = vk_to_physical_key(vk_code, lparam)
      let logical_key = vk_to_logical_key(vk_code)
      let is_extended = ((lparam >> 24) & 0x1 : Int64).to_int() != 0
      let repeat = ((lparam >> 30) & 0x1 : Int64).to_int() != 0
      let location = vk_to_key_location(vk_code, is_extended)
      let key_event = @core.KeyEvent::KeyEvent(
        physical_key,
        logical_key,
        logical_key,
        location,
        Pressed,
        repeat,
        None,
        None,
      )
      let modifiers = compute_modifiers_from_vk()
      app_state_queue_window_event(
        raw_id,
        KeyboardInput(None, key_event, false),
      )
      app_state_queue_window_event(raw_id, ModifiersChanged(modifiers))
    }
    31 => {
      let vk_code = wparam.to_int()
      let physical_key = vk_to_physical_key(vk_code, lparam)
      let logical_key = vk_to_logical_key(vk_code)
      let is_extended = ((lparam >> 24) & 0x1 : Int64).to_int() != 0
      let location = vk_to_key_location(vk_code, is_extended)
      let key_event = @core.KeyEvent::KeyEvent(
        physical_key,
        logical_key,
        logical_key,
        location,
        Released,
        false,
        None,
        None,
      )
      let modifiers = compute_modifiers_from_vk()
      app_state_queue_window_event(
        raw_id,
        KeyboardInput(None, key_event, false),
      )
      app_state_queue_window_event(raw_id, ModifiersChanged(modifiers))
    }
    32 => {
      let vk_code = wparam.to_int()
      let physical_key = vk_to_physical_key(vk_code, lparam)
      let logical_key = vk_to_logical_key(vk_code)
      let is_extended = ((lparam >> 24) & 0x1 : Int64).to_int() != 0
      let location = vk_to_key_location(vk_code, is_extended)
      let repeat = ((lparam >> 30) & 0x1 : Int64).to_int() != 0
      let key_event = @core.KeyEvent::KeyEvent(
        physical_key,
        logical_key,
        logical_key,
        location,
        Pressed,
        repeat,
        None,
        None,
      )
      app_state_queue_window_event(raw_id, KeyboardInput(None, key_event, true))
    }
    33 => {
      let vk_code = wparam.to_int()
      let physical_key = vk_to_physical_key(vk_code, lparam)
      let logical_key = vk_to_logical_key(vk_code)
      let is_extended = ((lparam >> 24) & 0x1 : Int64).to_int() != 0
      let location = vk_to_key_location(vk_code, is_extended)
      let key_event = @core.KeyEvent::KeyEvent(
        physical_key,
        logical_key,
        logical_key,
        location,
        Released,
        false,
        None,
        None,
      )
      app_state_queue_window_event(raw_id, KeyboardInput(None, key_event, true))
    }
    34 => {
      let char_code = wparam.to_int()
      if char_code >= 0x20 && char_code != 0x7F {
        let ch = char_code.unsafe_to_char()
        let text = ch.to_string()
        app_state_queue_window_event(raw_id, Ime(Commit(text)))
      }
    }
    35 => app_state_queue_window_event(raw_id, Ime(Enabled))
    36 => {
      let text = text_from_native_utf8_ptr(wparam, lparam.to_int())
      if wparam == 0 && lparam == 0 {
        app_state_queue_window_event(raw_id, Ime(Disabled))
      } else {
        app_state_queue_window_event(raw_id, Ime(Preedit(text, None)))
      }
    }
    37 => {
      let text = text_from_native_utf8_ptr(wparam, lparam.to_int())
      if text != "" {
        app_state_queue_window_event(raw_id, Ime(Commit(text)))
      }
    }
    _ => ()
  }
}

///|
fn dispatch_native_sync_query(raw_id : Int, kind : Int, _arg0 : Int) -> Int {
  match kind {
    1 => 0
    10 =>
      match app_state_window_handle(raw_id) {
        Some(_hwnd) => 1
        None => 0
      }
    _ => 0
  }
}

///|
fn vk_to_physical_key(vk_code : Int, _lparam : Int64) -> @core.PhysicalKey {
  let key_code = match vk_code {
    0x41 => @core.KeyCode::KeyA
    0x42 => KeyB
    0x43 => KeyC
    0x44 => KeyD
    0x45 => KeyE
    0x46 => KeyF
    0x47 => KeyG
    0x48 => KeyH
    0x49 => KeyI
    0x4A => KeyJ
    0x4B => KeyK
    0x4C => KeyL
    0x4D => KeyM
    0x4E => KeyN
    0x4F => KeyO
    0x50 => KeyP
    0x51 => KeyQ
    0x52 => KeyR
    0x53 => KeyS
    0x54 => KeyT
    0x55 => KeyU
    0x56 => KeyV
    0x57 => KeyW
    0x58 => KeyX
    0x59 => KeyY
    0x5A => KeyZ
    0x30 => Digit0
    0x31 => Digit1
    0x32 => Digit2
    0x33 => Digit3
    0x34 => Digit4
    0x35 => Digit5
    0x36 => Digit6
    0x37 => Digit7
    0x38 => Digit8
    0x39 => Digit9
    0x70 => F1
    0x71 => F2
    0x72 => F3
    0x73 => F4
    0x74 => F5
    0x75 => F6
    0x76 => F7
    0x77 => F8
    0x78 => F9
    0x79 => F10
    0x7A => F11
    0x7B => F12
    0x7C => F13
    0x7D => F14
    0x7E => F15
    0x7F => F16
    0x80 => F17
    0x81 => F18
    0x82 => F19
    0x83 => F20
    0x84 => F21
    0x85 => F22
    0x86 => F23
    0x87 => F24
    0x08 => Backspace
    0x09 => Tab
    0x0D => Enter
    0x1B => Escape
    0x20 => Space
    0x2D => Insert
    0x2E => Delete
    0x24 => Home
    0x23 => End
    0x21 => PageUp
    0x22 => PageDown
    0x25 => ArrowLeft
    0x26 => ArrowUp
    0x27 => ArrowRight
    0x28 => ArrowDown
    0x10 => ShiftLeft
    0x11 => ControlLeft
    0x12 => AltLeft
    0x5D => ContextMenu
    0x14 => CapsLock
    0x90 => NumLock
    0x91 => ScrollLock
    0x2C => PrintScreen
    0x13 => Pause
    0x60 => Numpad0
    0x61 => Numpad1
    0x62 => Numpad2
    0x63 => Numpad3
    0x64 => Numpad4
    0x65 => Numpad5
    0x66 => Numpad6
    0x67 => Numpad7
    0x68 => Numpad8
    0x69 => Numpad9
    0x6E => NumpadDecimal
    0x6A => NumpadMultiply
    0x6B => NumpadAdd
    0x6D => NumpadSubtract
    0x6F => NumpadDivide
    0x6C => NumpadEnter
    0xBB => Equal
    0xBD => Minus
    0xDB => BracketLeft
    0xDD => BracketRight
    0xBA => Semicolon
    0xDE => Quote
    0xDC => Backslash
    0xBC => Comma
    0xBE => Period
    0xBF => Slash
    0xC0 => Backquote
    _ => Unidentified
  }
  @core.PhysicalKey::from_key_code(key_code)
}

///|
fn vk_to_logical_key(vk_code : Int) -> @core.Key {
  match vk_code {
    0x08 => Named(Backspace)
    0x09 => Named(Tab)
    0x0D => Named(Enter)
    0x1B => Named(Escape)
    0x20 => Character(" ")
    0x21 => Named(PageUp)
    0x22 => Named(PageDown)
    0x23 => Named(End)
    0x24 => Named(Home)
    0x25 => Named(ArrowLeft)
    0x26 => Named(ArrowUp)
    0x27 => Named(ArrowRight)
    0x28 => Named(ArrowDown)
    0x2D => Named(Insert)
    0x2E => Named(Delete)
    0x10 => Named(Shift)
    0x11 => Named(Control)
    0x12 => Named(Alt)
    0x14 => Named(CapsLock)
    0x90 => Named(NumLock)
    0x91 => Named(ScrollLock)
    0x2C => Named(PrintScreen)
    0x13 => Named(Pause)
    0x5D => Named(ContextMenu)
    _ =>
      if vk_code >= 0x41 && vk_code <= 0x5A {
        Character((vk_code + 32).unsafe_to_char().to_string())
      } else if vk_code >= 0x30 && vk_code <= 0x39 {
        Character(vk_code.unsafe_to_char().to_string())
      } else if vk_code >= 0x70 && vk_code <= 0x87 {
        let f_num = vk_code - 0x70 + 1
        match f_num {
          1 => Named(F1)
          2 => Named(F2)
          3 => Named(F3)
          4 => Named(F4)
          5 => Named(F5)
          6 => Named(F6)
          7 => Named(F7)
          8 => Named(F8)
          9 => Named(F9)
          10 => Named(F10)
          11 => Named(F11)
          12 => Named(F12)
          13 => Named(F13)
          14 => Named(F14)
          15 => Named(F15)
          16 => Named(F16)
          17 => Named(F17)
          18 => Named(F18)
          19 => Named(F19)
          20 => Named(F20)
          _ => Unidentified(Windows(vk_code))
        }
      } else {
        Unidentified(Windows(vk_code))
      }
  }
}

///|
fn vk_to_key_location(vk_code : Int, is_extended : Bool) -> @core.KeyLocation {
  match vk_code {
    0x10 => if is_extended { Right } else { Left }
    0x11 => if is_extended { Right } else { Left }
    0x12 => if is_extended { Right } else { Left }
    _ => if vk_code >= 0x60 && vk_code <= 0x6F { Numpad } else { Standard }
  }
}

///|
fn compute_modifiers_from_vk() -> @core.Modifiers {
  let mut state = @core.ModifiersState::none()
  let mut keys = @core.ModifiersKeys::none()
  if native_get_key_state(0x10) != 0 {
    state = state.union(@core.ModifiersState::shift())
    keys = keys.union(@core.ModifiersKeys::lshift())
  }
  if native_get_key_state(0x11) != 0 {
    state = state.union(@core.ModifiersState::control())
    keys = keys.union(@core.ModifiersKeys::lcontrol())
  }
  if native_get_key_state(0x12) != 0 {
    state = state.union(@core.ModifiersState::alt())
    keys = keys.union(@core.ModifiersKeys::lalt())
  }
  @core.Modifiers::from_state(state, keys)
}
