///|
let web_event_animation_frame : Int = 1

///|
let web_event_timeout : Int = 2

///|
let web_event_proxy_wake : Int = 3

///|
let web_event_resize : Int = 10

///|
let web_event_focus : Int = 11

///|
let web_event_blur : Int = 12

///|
let web_event_pointer_enter : Int = 20

///|
let web_event_pointer_move : Int = 21

///|
let web_event_pointer_leave : Int = 22

///|
let web_event_pointer_down : Int = 23

///|
let web_event_pointer_up : Int = 24

///|
let web_event_wheel : Int = 30

///|
let web_event_key_down : Int = 40

///|
let web_event_key_up : Int = 41

///|
let web_event_ime_commit : Int = 42

///|
let web_event_ime_start : Int = 43

///|
let web_event_ime_preedit : Int = 44

///|
let web_event_ime_delete_surrounding : Int = 45

///|
let web_event_theme : Int = 50

///|
let web_event_drag_enter : Int = 60

///|
let web_event_drag_move : Int = 61

///|
let web_event_drag_drop : Int = 62

///|
let web_event_drag_leave : Int = 63

///|
fn web_mouse_button(button : Int) -> @core.MouseButton {
  match @core.MouseButton::try_from_u8(button) {
    Some(mouse) => mouse
    None => Left
  }
}

///|
fn web_element_state(pressed : Bool) -> @core.ElementState {
  if pressed {
    Pressed
  } else {
    Released
  }
}

///|
fn web_key_from_text(text : String) -> @core.Key {
  match text {
    "Enter" => Named(Enter)
    "Tab" => Named(Tab)
    "Backspace" => Named(Backspace)
    "Escape" => Named(Escape)
    "Shift" => Named(Shift)
    "Control" => Named(Control)
    "Alt" => Named(Alt)
    "Meta" => Named(Meta)
    "CapsLock" => Named(CapsLock)
    "ArrowLeft" => Named(ArrowLeft)
    "ArrowRight" => Named(ArrowRight)
    "ArrowUp" => Named(ArrowUp)
    "ArrowDown" => Named(ArrowDown)
    "Home" => Named(Home)
    "End" => Named(End)
    "PageUp" => Named(PageUp)
    "PageDown" => Named(PageDown)
    "Insert" => Named(Insert)
    "Delete" => Named(Delete)
    _ =>
      if text.length() == 1 {
        Character(text)
      } else {
        Unidentified(Web(text))
      }
  }
}

///|
fn web_key_code_from_code(code : String) -> @core.KeyCode {
  match code {
    "KeyA" => KeyA
    "KeyB" => KeyB
    "KeyC" => KeyC
    "KeyD" => KeyD
    "KeyE" => KeyE
    "KeyF" => KeyF
    "KeyG" => KeyG
    "KeyH" => KeyH
    "KeyI" => KeyI
    "KeyJ" => KeyJ
    "KeyK" => KeyK
    "KeyL" => KeyL
    "KeyM" => KeyM
    "KeyN" => KeyN
    "KeyO" => KeyO
    "KeyP" => KeyP
    "KeyQ" => KeyQ
    "KeyR" => KeyR
    "KeyS" => KeyS
    "KeyT" => KeyT
    "KeyU" => KeyU
    "KeyV" => KeyV
    "KeyW" => KeyW
    "KeyX" => KeyX
    "KeyY" => KeyY
    "KeyZ" => KeyZ
    "Digit0" => Digit0
    "Digit1" => Digit1
    "Digit2" => Digit2
    "Digit3" => Digit3
    "Digit4" => Digit4
    "Digit5" => Digit5
    "Digit6" => Digit6
    "Digit7" => Digit7
    "Digit8" => Digit8
    "Digit9" => Digit9
    "Enter" => Enter
    "Tab" => Tab
    "Backspace" => Backspace
    "Escape" => Escape
    "Space" => Space
    "ArrowLeft" => ArrowLeft
    "ArrowRight" => ArrowRight
    "ArrowUp" => ArrowUp
    "ArrowDown" => ArrowDown
    "ShiftLeft" => ShiftLeft
    "ShiftRight" => ShiftRight
    "ControlLeft" => ControlLeft
    "ControlRight" => ControlRight
    "AltLeft" => AltLeft
    "AltRight" => AltRight
    "MetaLeft" => MetaLeft
    "MetaRight" => MetaRight
    _ => Unidentified
  }
}

///|
fn web_key_location(code : String) -> @core.KeyLocation {
  match code {
    "ShiftLeft" | "ControlLeft" | "AltLeft" | "MetaLeft" => Left
    "ShiftRight" | "ControlRight" | "AltRight" | "MetaRight" => Right
    "Numpad0"
    | "Numpad1"
    | "Numpad2"
    | "Numpad3"
    | "Numpad4"
    | "Numpad5"
    | "Numpad6"
    | "Numpad7"
    | "Numpad8"
    | "Numpad9"
    | "NumpadEnter" => Numpad
    _ => Standard
  }
}

///|
fn web_key_event(code : String, key : String, pressed : Bool) -> @core.KeyEvent {
  let logical_key = web_key_from_text(key)
  let physical_key = @core.PhysicalKey::from_key_code(
    web_key_code_from_code(code),
  )
  let text = match logical_key {
    Character(text) => if text == "" { None } else { Some(text) }
    Named(Enter) => Some("\r")
    Named(Tab) => Some("\t")
    _ => None
  }
  KeyEvent(
    physical_key,
    logical_key,
    logical_key,
    web_key_location(code),
    web_element_state(pressed),
    false,
    text,
    None,
  )
}

///|
fn web_drag_paths(text : String) -> Array[String] {
  let paths : Array[String] = []
  if text != "" {
    for path_view in text.split("\n") {
      let path = path_view.to_owned()
      if path != "" {
        paths.push(path)
      }
    }
  }
  paths
}

///|
fn dispatch_web_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text : String,
) -> Unit {
  match kind {
    k if k == web_event_animation_frame =>
      app_state_queue_callback(NewEvents(Poll))
    k if k == web_event_timeout => {
      let now = argd.to_int64()
      app_state_queue_callback(NewEvents(ResumeTimeReached(now, now)))
    }
    k if k == web_event_proxy_wake => app_state_queue_callback(ProxyWakeUp)
    k if k == web_event_resize => {
      let size : @dpi.PhysicalSize = PhysicalSize(arg0, arg1)
      let old_scale = app_state_window_scale_factor(raw_id)
      app_state_set_window_surface_size(raw_id, size)
      let new_scale = web_normalize_scale_factor(argd)
      app_state_set_window_scale_factor(raw_id, new_scale)
      if new_scale != old_scale {
        app_state_queue_window_event(
          raw_id,
          ScaleFactorChanged(new_scale, SurfaceSizeWriter(size)),
        )
      }
      app_state_queue_window_event(raw_id, SurfaceResized(size))
    }
    k if k == web_event_focus => {
      app_state_set_window_focused(raw_id, true)
      app_state_queue_window_event(raw_id, Focused(true))
    }
    k if k == web_event_blur => {
      app_state_set_window_focused(raw_id, false)
      app_state_queue_window_event(raw_id, Focused(false))
    }
    k if k == web_event_pointer_enter => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        PointerEntered(None, position, true, Mouse),
      )
    }
    k if k == web_event_pointer_move => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        PointerMoved(None, position, true, Mouse),
      )
    }
    k if k == web_event_pointer_leave => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        PointerLeft(None, Some(position), true, Mouse),
      )
    }
    k if k == web_event_pointer_down || k == web_event_pointer_up => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        PointerButton(
          None,
          web_element_state(k == web_event_pointer_down),
          position,
          true,
          Mouse(web_mouse_button(argd.to_int())),
        ),
      )
    }
    k if k == web_event_wheel =>
      app_state_queue_window_event(
        raw_id,
        MouseWheel(
          None,
          PixelDelta(PhysicalPositionF64(arg0.to_double(), arg1.to_double())),
          Moved,
        ),
      )
    k if k == web_event_drag_enter => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        DragEntered(web_drag_paths(text), position),
      )
    }
    k if k == web_event_drag_move => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(raw_id, DragMoved(position))
    }
    k if k == web_event_drag_drop => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        DragDropped(web_drag_paths(text), position),
      )
    }
    k if k == web_event_drag_leave => {
      let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(raw_id, DragLeft(Some(position)))
    }
    k if k == web_event_key_down || k == web_event_key_up =>
      app_state_queue_window_event(
        raw_id,
        KeyboardInput(
          None,
          web_key_event(text, text, k == web_event_key_down),
          false,
        ),
      )
    k if k == web_event_ime_commit =>
      app_state_queue_window_event(raw_id, Ime(Commit(text)))
    k if k == web_event_ime_start =>
      app_state_queue_window_event(raw_id, Ime(Enabled))
    k if k == web_event_ime_preedit => {
      let cursor : @core.ImeCursorRange? = if arg0 >= 0 && arg1 >= arg0 {
        Some(ImeCursorRange(arg0, arg1))
      } else {
        None
      }
      app_state_queue_window_event(raw_id, Ime(Preedit(text, cursor)))
    }
    k if k == web_event_ime_delete_surrounding =>
      app_state_queue_window_event(raw_id, Ime(DeleteSurrounding(arg0, arg1)))
    k if k == web_event_theme => {
      let theme : @core.Theme = if arg0 == 1 { Dark } else { Light }
      app_state_queue_window_event(raw_id, ThemeChanged(theme))
    }
    _ => ()
  }
}
