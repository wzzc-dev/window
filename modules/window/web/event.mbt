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
    None => @core.MouseButton::Left
  }
}

///|
fn web_element_state(pressed : Bool) -> @core.ElementState {
  if pressed {
    @core.ElementState::Pressed
  } else {
    @core.ElementState::Released
  }
}

///|
fn web_key_from_text(text : String) -> @core.Key {
  match text {
    "Enter" => @core.Key::Named(@core.NamedKey::Enter)
    "Tab" => @core.Key::Named(@core.NamedKey::Tab)
    "Backspace" => @core.Key::Named(@core.NamedKey::Backspace)
    "Escape" => @core.Key::Named(@core.NamedKey::Escape)
    "Shift" => @core.Key::Named(@core.NamedKey::Shift)
    "Control" => @core.Key::Named(@core.NamedKey::Control)
    "Alt" => @core.Key::Named(@core.NamedKey::Alt)
    "Meta" => @core.Key::Named(@core.NamedKey::Meta)
    "CapsLock" => @core.Key::Named(@core.NamedKey::CapsLock)
    "ArrowLeft" => @core.Key::Named(@core.NamedKey::ArrowLeft)
    "ArrowRight" => @core.Key::Named(@core.NamedKey::ArrowRight)
    "ArrowUp" => @core.Key::Named(@core.NamedKey::ArrowUp)
    "ArrowDown" => @core.Key::Named(@core.NamedKey::ArrowDown)
    "Home" => @core.Key::Named(@core.NamedKey::Home)
    "End" => @core.Key::Named(@core.NamedKey::End)
    "PageUp" => @core.Key::Named(@core.NamedKey::PageUp)
    "PageDown" => @core.Key::Named(@core.NamedKey::PageDown)
    "Insert" => @core.Key::Named(@core.NamedKey::Insert)
    "Delete" => @core.Key::Named(@core.NamedKey::Delete)
    _ =>
      if text.length() == 1 {
        @core.Key::Character(text)
      } else {
        @core.Key::Unidentified(@core.NativeKey::Web(text))
      }
  }
}

///|
fn web_key_code_from_code(code : String) -> @core.KeyCode {
  match code {
    "KeyA" => @core.KeyCode::KeyA
    "KeyB" => @core.KeyCode::KeyB
    "KeyC" => @core.KeyCode::KeyC
    "KeyD" => @core.KeyCode::KeyD
    "KeyE" => @core.KeyCode::KeyE
    "KeyF" => @core.KeyCode::KeyF
    "KeyG" => @core.KeyCode::KeyG
    "KeyH" => @core.KeyCode::KeyH
    "KeyI" => @core.KeyCode::KeyI
    "KeyJ" => @core.KeyCode::KeyJ
    "KeyK" => @core.KeyCode::KeyK
    "KeyL" => @core.KeyCode::KeyL
    "KeyM" => @core.KeyCode::KeyM
    "KeyN" => @core.KeyCode::KeyN
    "KeyO" => @core.KeyCode::KeyO
    "KeyP" => @core.KeyCode::KeyP
    "KeyQ" => @core.KeyCode::KeyQ
    "KeyR" => @core.KeyCode::KeyR
    "KeyS" => @core.KeyCode::KeyS
    "KeyT" => @core.KeyCode::KeyT
    "KeyU" => @core.KeyCode::KeyU
    "KeyV" => @core.KeyCode::KeyV
    "KeyW" => @core.KeyCode::KeyW
    "KeyX" => @core.KeyCode::KeyX
    "KeyY" => @core.KeyCode::KeyY
    "KeyZ" => @core.KeyCode::KeyZ
    "Digit0" => @core.KeyCode::Digit0
    "Digit1" => @core.KeyCode::Digit1
    "Digit2" => @core.KeyCode::Digit2
    "Digit3" => @core.KeyCode::Digit3
    "Digit4" => @core.KeyCode::Digit4
    "Digit5" => @core.KeyCode::Digit5
    "Digit6" => @core.KeyCode::Digit6
    "Digit7" => @core.KeyCode::Digit7
    "Digit8" => @core.KeyCode::Digit8
    "Digit9" => @core.KeyCode::Digit9
    "Enter" => @core.KeyCode::Enter
    "Tab" => @core.KeyCode::Tab
    "Backspace" => @core.KeyCode::Backspace
    "Escape" => @core.KeyCode::Escape
    "Space" => @core.KeyCode::Space
    "ArrowLeft" => @core.KeyCode::ArrowLeft
    "ArrowRight" => @core.KeyCode::ArrowRight
    "ArrowUp" => @core.KeyCode::ArrowUp
    "ArrowDown" => @core.KeyCode::ArrowDown
    "ShiftLeft" => @core.KeyCode::ShiftLeft
    "ShiftRight" => @core.KeyCode::ShiftRight
    "ControlLeft" => @core.KeyCode::ControlLeft
    "ControlRight" => @core.KeyCode::ControlRight
    "AltLeft" => @core.KeyCode::AltLeft
    "AltRight" => @core.KeyCode::AltRight
    "MetaLeft" => @core.KeyCode::MetaLeft
    "MetaRight" => @core.KeyCode::MetaRight
    _ => @core.KeyCode::Unidentified
  }
}

///|
fn web_key_location(code : String) -> @core.KeyLocation {
  match code {
    "ShiftLeft" | "ControlLeft" | "AltLeft" | "MetaLeft" =>
      @core.KeyLocation::Left
    "ShiftRight" | "ControlRight" | "AltRight" | "MetaRight" =>
      @core.KeyLocation::Right
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
    | "NumpadEnter" => @core.KeyLocation::Numpad
    _ => @core.KeyLocation::Standard
  }
}

///|
fn web_key_event(code : String, key : String, pressed : Bool) -> @core.KeyEvent {
  let logical_key = web_key_from_text(key)
  let physical_key = @core.PhysicalKey::from_key_code(
    web_key_code_from_code(code),
  )
  let text = match logical_key {
    @core.Key::Character(text) => if text == "" { None } else { Some(text) }
    @core.Key::Named(@core.NamedKey::Enter) => Some("\r")
    @core.Key::Named(@core.NamedKey::Tab) => Some("\t")
    _ => None
  }
  @core.KeyEvent::KeyEvent(
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
      app_state_queue_callback(NewEvents(@core.StartCause::Poll))
    k if k == web_event_timeout => {
      let now = argd.to_int64()
      app_state_queue_callback(
        NewEvents(@core.StartCause::ResumeTimeReached(now, now)),
      )
    }
    k if k == web_event_proxy_wake => app_state_queue_callback(ProxyWakeUp)
    k if k == web_event_resize => {
      let size = @dpi.PhysicalSize::PhysicalSize(arg0, arg1)
      let old_scale = app_state_window_scale_factor(raw_id)
      app_state_set_window_surface_size(raw_id, size)
      let new_scale = web_normalize_scale_factor(argd)
      app_state_set_window_scale_factor(raw_id, new_scale)
      if new_scale != old_scale {
        app_state_queue_window_event(
          raw_id,
          @core.WindowEvent::ScaleFactorChanged(
            new_scale,
            @core.SurfaceSizeWriter::SurfaceSizeWriter(size),
          ),
        )
      }
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::SurfaceResized(size),
      )
    }
    k if k == web_event_focus => {
      app_state_set_window_focused(raw_id, true)
      app_state_queue_window_event(raw_id, @core.WindowEvent::Focused(true))
    }
    k if k == web_event_blur => {
      app_state_set_window_focused(raw_id, false)
      app_state_queue_window_event(raw_id, @core.WindowEvent::Focused(false))
    }
    k if k == web_event_pointer_enter => {
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
    k if k == web_event_pointer_move => {
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
    k if k == web_event_pointer_leave => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::PointerLeft(
          None,
          Some(position),
          true,
          @core.PointerKind::Mouse,
        ),
      )
    }
    k if k == web_event_pointer_down || k == web_event_pointer_up => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::PointerButton(
          None,
          web_element_state(k == web_event_pointer_down),
          position,
          true,
          @core.ButtonSource::Mouse(web_mouse_button(argd.to_int())),
        ),
      )
    }
    k if k == web_event_wheel =>
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
    k if k == web_event_drag_enter => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::DragEntered(web_drag_paths(text), position),
      )
    }
    k if k == web_event_drag_move => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::DragMoved(position),
      )
    }
    k if k == web_event_drag_drop => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::DragDropped(web_drag_paths(text), position),
      )
    }
    k if k == web_event_drag_leave => {
      let position = @dpi.PhysicalPositionF64::PhysicalPositionF64(
        arg0.to_double(),
        arg1.to_double(),
      )
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::DragLeft(Some(position)),
      )
    }
    k if k == web_event_key_down || k == web_event_key_up =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::KeyboardInput(
          None,
          web_key_event(text, text, k == web_event_key_down),
          false,
        ),
      )
    k if k == web_event_ime_commit =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::Ime(@core.Ime::Commit(text)),
      )
    k if k == web_event_ime_start =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::Ime(@core.Ime::Enabled),
      )
    k if k == web_event_ime_preedit => {
      let cursor = if arg0 >= 0 && arg1 >= arg0 {
        Some(@core.ImeCursorRange::ImeCursorRange(arg0, arg1))
      } else {
        None
      }
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::Ime(@core.Ime::Preedit(text, cursor)),
      )
    }
    k if k == web_event_ime_delete_surrounding =>
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::Ime(@core.Ime::DeleteSurrounding(arg0, arg1)),
      )
    k if k == web_event_theme => {
      let theme = if arg0 == 1 { @core.Theme::Dark } else { @core.Theme::Light }
      app_state_queue_window_event(
        raw_id,
        @core.WindowEvent::ThemeChanged(theme),
      )
    }
    _ => ()
  }
}
