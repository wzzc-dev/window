///|
/// Ordered native commands kept stable for native bridges and host-sim callers.
pub(all) enum HostCmd {
  Start
  Resume
  Pause
  Stop
  SurfaceInit(UInt64, UInt64, Int32, Int32, Double)
  SurfaceTerm
  SurfaceResize(Int32, Int32, Double)
  PointerMoved(Double, Double)
  PointerButton(Bool, Double, Double)
  KeyboardText(String)
  /// Mouse wheel / trackpad scroll with the pointer position that produced it.
  /// `x, y` are the cursor position; `delta_x, delta_y` are already **pixels**
  /// (the native bridge converts wheel degrees and touchpad units itself), so the
  /// runtime must not apply a second line-to-pixel factor.
  Scroll(Double, Double, Double, Double)
  /// Non-character key press/release: platform key code, modifier bitmask,
  /// and 1 for press / 0 for release.
  KeyPress(Int32, Int32, Bool)
  MemoryWarning
  Destroy
}

///|
/// Wheel cursor positions, one per queued wheel event. A drain can push several
/// wheel events before the loop consumes them (fast trackpads), so the positions
/// are kept in a queue and popped in order instead of a single slot that the last
/// event would overwrite.
let scroll_cursors : Ref[Array[(Double, Double)]] = Ref([])

///|
let embedded_dispatch_kernel : Ref[@embedded_dispatch.EmbeddedDispatchQueue] = Ref(
  @embedded_dispatch.EmbeddedDispatchQueue::new(),
)

///|
pub fn host_reset_for_test() -> Unit {
  embedded_dispatch_kernel.val = @embedded_dispatch.EmbeddedDispatchQueue::new()
  app_state_reset_for_test()
  host_reset_native_queue()
}

///|
pub fn host_push(cmd : HostCmd) -> Unit {
  embedded_dispatch_kernel.val.push(host_command_to_embedded(cmd))
}

///|
/// Pushes one host command. A `KeyPress` expands to two dispatch commands —
/// `ModifiersChanged` followed by the key event — because the backend keeps
/// modifier state on the window and only updates it from that event, so a
/// standalone `KeyboardInput` would always decode with stale modifiers.
fn host_push_command(cmd : HostCmd) -> Unit {
  match cmd {
    Scroll(x, y, delta_x, delta_y) => {
      // Record the cursor position without dispatching a pointer event: a wheel
      // notch must not synthesise `PointerMoved`, because that delivers a full
      // pointer event (and its hover repaint) per notch and made scrolling
      // stutter. `scroll_cursor` is read by the host loop when it routes the
      // wheel.
      // The delta is already in **pixels**: the host bridge converts the
      // platform unit (wheel degrees, touchpad px) before pushing. Sending it as
      // `LineDelta` would multiply it by the host's 40 px line extent a second
      // time, which is what made one notch scroll most of a screen.
      scroll_cursors.val.push((x, y))
      embedded_dispatch_kernel.val.push(
        WindowEvent(
          MouseWheel(
            None,
            PixelDelta(PhysicalPositionF64(delta_x, delta_y)),
            @core.TouchPhase::Moved,
          ),
        ),
      )
    }
    KeyPress(key_code, key_modifiers, pressed) => {
      embedded_dispatch_kernel.val.push(
        WindowEvent(ModifiersChanged(harmonyos_modifiers(key_modifiers))),
      )
      embedded_dispatch_kernel.val.push(
        WindowEvent(harmonyos_key_event(key_code, key_modifiers, pressed)),
      )
    }
    _ => host_push(cmd)
  }
}

///|
/// Exposes the command decode for whitebox tests.

///|
/// Pushes through the production path (`host_push_command`, which expands Scroll
/// and KeyPress into their real event shapes) and returns the queued commands.
/// `host_command_to_embedded_for_test` only covers the plain mapping and would
/// miss those expansions.
pub fn host_push_command_for_test(
  cmd : HostCmd,
) -> Array[@embedded_dispatch.EmbeddedDispatchEffect] {
  host_push_command(cmd)
  embedded_dispatch_kernel.val.drain()
}

///|
pub fn host_command_to_embedded_for_test(
  cmd : HostCmd,
) -> @embedded_dispatch.EmbeddedDispatchCommand {
  host_command_to_embedded(cmd)
}

///|
fn host_command_to_embedded(
  cmd : HostCmd,
) -> @embedded_dispatch.EmbeddedDispatchCommand {
  match cmd {
    Start => Start
    Resume => Resume
    Pause => Pause
    Stop => Stop
    SurfaceInit(handle, token, width, height, scale_factor) =>
      SurfaceInit(handle, token, width, height, scale_factor)
    SurfaceTerm => SurfaceTerm
    SurfaceResize(width, height, scale_factor) =>
      SurfaceResize(width, height, scale_factor)
    PointerMoved(x, y) =>
      WindowEvent(
        PointerMoved(
          None,
          PhysicalPositionF64(x, y),
          true,
          Touch(@core.FingerId::from_raw(0), None),
        ),
      )
    PointerButton(pressed, x, y) =>
      WindowEvent(
        PointerButton(
          None,
          if pressed {
            Pressed
          } else {
            Released
          },
          PhysicalPositionF64(x, y),
          true,
          Touch(@core.FingerId::from_raw(0), None),
        ),
      )
    KeyboardText(text) => WindowEvent(Ime(Commit(text)))
    Scroll(_, _, delta_x, delta_y) =>
      WindowEvent(
        MouseWheel(None, LineDelta(delta_x, delta_y), @core.TouchPhase::Moved),
      )
    KeyPress(key_code, key_modifiers, pressed) =>
      WindowEvent(harmonyos_key_event(key_code, key_modifiers, pressed))
    MemoryWarning => MemoryWarning
    Destroy => Destroy
  }
}

///|
fn host_surfaces_allowed() -> Bool {
  embedded_dispatch_kernel.val.surfaces_allowed()
}

///|
fn host_apply_surface_to_windows(
  surface : @embedded_dispatch.EmbeddedDispatchSurface,
) -> Unit {
  for entry in app_state_runtime.val.window_entries {
    if surface.handle != 0UL {
      entry.surface_handle = surface.handle
      entry.surface_token = surface.token
    }
    entry.width = surface.physical_size.width
    entry.height = surface.physical_size.height
    entry.scale_factor = surface.scale_factor
    app_state_queue_window_event(
      @core.WindowId::from_raw(entry.raw_id),
      SurfaceResized(surface.physical_size),
    )
    app_state_queue_window_event(
      @core.WindowId::from_raw(entry.raw_id),
      ScaleFactorChanged(
        surface.scale_factor,
        SurfaceSizeWriter(surface.physical_size),
      ),
    )
    app_state_request_redraw(entry.raw_id)
  }
}

///|
fn host_invalidate_window_handles() -> Unit {
  for entry in app_state_runtime.val.window_entries {
    entry.surface_handle = 0UL
    entry.surface_token = 0UL
  }
}

///|
fn host_apply_effect(
  effect : @embedded_dispatch.EmbeddedDispatchEffect,
) -> Bool {
  match effect {
    Resumed => {
      app_state_queue_lifecycle(Resumed)
      false
    }
    CanCreateSurfaces => {
      app_state_queue_lifecycle(CanCreateSurfaces)
      false
    }
    SurfaceChanged(surface) => {
      host_apply_surface_to_windows(surface)
      false
    }
    SurfaceInvalidated => {
      host_invalidate_window_handles()
      false
    }
    DestroySurfaces => {
      app_state_queue_lifecycle(DestroySurfaces)
      false
    }
    Suspended => {
      app_state_queue_lifecycle(Suspended)
      false
    }
    WindowEvent(event) => {
      for entry in app_state_runtime.val.window_entries {
        app_state_queue_window_event(
          @core.WindowId::from_raw(entry.raw_id),
          event,
        )
        break
      }
      false
    }
    MemoryWarning => {
      app_state_queue_lifecycle(MemoryWarning)
      false
    }
    Exit(code) => {
      app_state_request_exit(code)
      true
    }
  }
}

///|
/// Consumes the wheel cursor recorded by the last `Scroll` command. Returns
/// `None` when the pending event is not a wheel.
pub fn host_take_scroll_cursor() -> (Double, Double)? {
  let queued = scroll_cursors.val
  if queued.length() == 0 {
    return None
  }
  let first = queued[0]
  let rest : Array[(Double, Double)] = []
  for i in 1..<queued.length() {
    rest.push(queued[i])
  }
  scroll_cursors.val = rest
  Some(first)
}

///|
fn host_drain_into_app_state() -> Bool {
  let mut exit_loop = false
  for effect in embedded_dispatch_kernel.val.drain() {
    if host_apply_effect(effect) {
      exit_loop = true
    }
  }
  exit_loop
}

///|
fn host_default_window_metrics() -> (Int32, Int32, Double, UInt64, UInt64) {
  match embedded_dispatch_kernel.val.surface() {
    Some(surface) =>
      (
        surface.physical_size.width,
        surface.physical_size.height,
        surface.scale_factor,
        surface.handle,
        surface.token,
      )
    None => (1, 1, 1.0, 0UL, 0UL)
  }
}

///|
/// Character form of an OHOS letter/digit key, used when the key arrives as a
/// shortcut chord (Ctrl+A, Ctrl+Z) so `moui/core` shortcut predicates can match
/// on the character name.
fn harmonyos_key_character(key_code : Int32, shift : Bool) -> String? {
  // Letters A-Z: KEYCODE_A = 2017 .. KEYCODE_Z = 2042.
  if key_code >= 2017 && key_code <= 2042 {
    let offset = key_code - 2017
    let lower = (0x61 + offset).unsafe_to_char()
    let upper = (0x41 + offset).unsafe_to_char()
    return Some(if shift { upper.to_string() } else { lower.to_string() })
  }
  // Digits 0-9: KEYCODE_0 = 2000 .. KEYCODE_9 = 2009.
  if key_code >= 2000 && key_code <= 2009 {
    return Some((0x30 + (key_code - 2000)).unsafe_to_char().to_string())
  }
  None
}

///|
/// OHOS modifier bitmask (measured on device: bit0 = Ctrl, bit1 = Shift,
/// bit2 = Alt) to the window-core modifier state.
fn harmonyos_modifiers(key_modifiers : Int32) -> @core.Modifiers {
  @core.Modifiers::Modifiers(
    (key_modifiers & 0x2) != 0,
    (key_modifiers & 0x1) != 0,
    (key_modifiers & 0x4) != 0,
    false,
  )
}

///|
/// Maps an OHOS key code plus its modifier bitmask into a window-core
/// `KeyEvent`. Character keys keep travelling through
/// `MBW_HARMONYOS_HOST_KEYBOARD_CODEPOINT`, so this only needs the named keys a
/// text field reacts to: Delete/Backspace, movement, submit, and shortcuts such
/// as Ctrl+A.
///
/// OHOS key codes (see multimodalinput/oh_key_code.h): KEYCODE_ENTER = 2054,
/// KEYCODE_DEL = 2055 (Backspace), KEYCODE_FORWARD_DEL = 2071 (Delete),
/// KEYCODE_TAB = 2049, KEYCODE_ESCAPE = 2070, KEYCODE_DPAD_* = 2012..2015,
/// KEYCODE_MOVE_HOME = 2081, KEYCODE_MOVE_END = 2082.
fn harmonyos_key_event(
  key_code : Int32,
  key_modifiers : Int32,
  pressed : Bool,
) -> @core.WindowEvent {
  // OHOS modifier bitmask measured on device: bit0 = Ctrl, bit1 = Shift,
  // bit2 = Alt. (The mapping is not in a public header; a simulated Ctrl+A
  // reports modifiers=1 on the 'A' key, Shift 2, Alt 4.)
  let control = (key_modifiers & 0x1) != 0
  let shift = (key_modifiers & 0x2) != 0
  let alt = (key_modifiers & 0x4) != 0
  let meta = false
  let named = harmonyos_named_key(key_code)
  let state = if pressed {
    @core.ElementState::Pressed
  } else {
    @core.ElementState::Released
  }
  // Shortcut matching in `moui/core` compares against a character name ("a",
  // "z", ...), so a letter arriving as a shortcut chord must carry its character
  // form instead of staying an unidentified native code.
  let logical_key = match named {
    Some(named) => @core.Key::Named(named)
    None =>
      match harmonyos_key_character(key_code, shift) {
        Some(text) => @core.Key::Character(text)
        None => @core.Key::Unidentified(Ohos(key_code))
      }
  }
  let key_event = @core.KeyEvent::KeyEvent(
    @core.PhysicalKey::Unidentified(Ohos(key_code)),
    logical_key,
    logical_key,
    @core.KeyLocation::Standard,
    state,
    false,
    None,
    None,
  )
  // Modifier state travels with the event through `ModifiersChanged`, which the
  // window keeps for the session; the key event itself carries the resolved
  // logical key and text.
  ignore((shift, control, alt, meta))
  KeyboardInput(None, key_event, false)
}

///|
/// OHOS key code -> window-core named key, for the keys a hosted text field or
/// shortcut layer reacts to. Unknown codes stay `Ohos(raw)` so nothing is lost.
fn harmonyos_named_key(key_code : Int32) -> @core.NamedKey? {
  Some(
    match key_code {
      2054 => @core.NamedKey::Enter
      2055 => @core.NamedKey::Backspace
      2071 => @core.NamedKey::Delete
      2049 => @core.NamedKey::Tab
      2070 => @core.NamedKey::Escape
      2012 => @core.NamedKey::ArrowUp
      2013 => @core.NamedKey::ArrowDown
      2014 => @core.NamedKey::ArrowLeft
      2015 => @core.NamedKey::ArrowRight
      2081 => @core.NamedKey::Home
      2082 => @core.NamedKey::End
      _ => return None
    },
  )
}
