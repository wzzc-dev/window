///|
/// Scrolling must decode to `MouseWheel`; before the SCROLL host event existed
/// the hosted surface never received a wheel event at all.
test "harmonyos scroll decodes to a pixel mouse wheel event" {
  // The production path converts the platform unit to pixels before pushing, so
  // the event must carry `PixelDelta`. A `LineDelta` here would be multiplied by
  // the host's 40 px line extent and scroll most of a screen per notch.
  let queued = host_push_command_for_test(Scroll(10.0, 20.0, 0.0, -22.0))
  inspect(queued.length(), content="1")
  let wheel = match queued[0] {
    WindowEvent(event) => Some(event)
    _ => None
  }
  match wheel {
    Some(MouseWheel(_, PixelDelta(_), _)) => ()
    _ => fail("scroll did not decode to a pixel mouse wheel event")
  }
  // The cursor position is recorded beside the event for the host loop.
  match host_take_scroll_cursor() {
    Some(_) => ()
    None => fail("scroll cursor was not recorded")
  }
}

///|
/// Backspace must decode as a named key, not text: the codepoint channel cannot
/// express deletion, which is why the key was dead on device.
test "harmonyos backspace decodes to a named key" {
  let decoded = host_command_to_embedded_for_test(KeyPress(2055, 0, true))
  inspect(decoded is WindowEvent(KeyboardInput(_, _, false)), content="true")
}

///|
/// A letter pressed in a shortcut chord must carry its character form, otherwise
/// `moui/core` shortcut matching (Ctrl+A) cannot see the key name.
test "harmonyos ctrl+a decodes a character key with ctrl modifier" {
  let decoded = host_command_to_embedded_for_test(KeyPress(2017, 1, true))
  match decoded {
    WindowEvent(KeyboardInput(_, event, _)) =>
      inspect(event.logical_key() is Character("a"), content="true")
    _ => fail("ctrl+a did not decode to a keyboard input event")
  }
}

///|
/// Ctrl+C must decode to a key event whose character form is "c", because
/// `keyboard_service_command_intent` matches on `event.key == "c"`. This is the
/// predicate that decides whether the clipboard service is reached at all.
test "harmonyos ctrl+c decodes a character key named c" {
  let decoded = host_command_to_embedded_for_test(KeyPress(2019, 1, true))
  match decoded {
    WindowEvent(KeyboardInput(_, event, _)) =>
      inspect(event.logical_key() is Character("c"), content="true")
    _ => fail("ctrl+c did not decode to a keyboard input event")
  }
}

///|
/// Ctrl+V and Ctrl+X use the same character-form requirement.
test "harmonyos ctrl+v and ctrl+x decode character keys" {
  match host_command_to_embedded_for_test(KeyPress(2038, 1, true)) {
    WindowEvent(KeyboardInput(_, event, _)) =>
      inspect(event.logical_key() is Character("v"), content="true")
    _ => fail("ctrl+v did not decode to a keyboard input event")
  }
  match host_command_to_embedded_for_test(KeyPress(2040, 1, true)) {
    WindowEvent(KeyboardInput(_, event, _)) =>
      inspect(event.logical_key() is Character("x"), content="true")
    _ => fail("ctrl+x did not decode to a keyboard input event")
  }
}
