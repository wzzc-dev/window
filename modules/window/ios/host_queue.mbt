///|
/// Ordered native commands kept stable for native bridges and host-sim callers.
pub(all) enum HostCmd {
  Start
  Resume
  Pause
  Stop
  SurfaceInit(UInt64, UInt64, Int, Int, Double)
  SurfaceTerm
  SurfaceResize(Int, Int, Double)
  PointerMoved(Double, Double)
  PointerButton(Bool, Double, Double)
  PointerPhase(Int, Double, Double)
  Scroll(Double, Double, Double, Double, Int)
  KeyboardText(String)
  ImeEvent(Int, String, Int, Int)
  MemoryWarning
  Destroy
}

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
  for command in host_commands_to_embedded(cmd) {
    embedded_dispatch_kernel.val.push(command)
  }
}

///|
fn host_commands_to_embedded(
  cmd : HostCmd,
) -> Array[@embedded_dispatch.EmbeddedDispatchCommand] {
  match cmd {
    Start => [Start]
    Resume => [Resume]
    Pause => [Pause]
    Stop => [Stop]
    SurfaceInit(handle, token, width, height, scale_factor) =>
      [SurfaceInit(handle, token, width, height, scale_factor)]
    SurfaceTerm => [SurfaceTerm]
    SurfaceResize(width, height, scale_factor) =>
      [SurfaceResize(width, height, scale_factor)]
    PointerMoved(x, y) => [embedded_pointer_moved(x, y)]
    PointerButton(pressed, x, y) => [embedded_pointer_button(pressed, x, y)]
    PointerPhase(phase, x, y) => {
      let commands = [embedded_pointer_moved(x, y)]
      if phase == 0 {
        commands.push(embedded_pointer_button(true, x, y))
      } else if phase == 2 || phase == 3 {
        commands.push(embedded_pointer_button(false, x, y))
      }
      commands
    }
    Scroll(_x, _y, dx, dy, phase) =>
      [
        WindowEvent(
          MouseWheel(
            None,
            PixelDelta(PhysicalPositionF64(dx, dy)),
            match phase {
              0 => Started
              1 => Moved
              2 => Ended
              _ => Cancelled
            },
          ),
        ),
      ]
    KeyboardText(text) => [WindowEvent(Ime(Commit(text)))]
    ImeEvent(kind, text, start, end) =>
      match ime_event_to_window_ime(kind, text, start, end) {
        Some(ime) => [WindowEvent(Ime(ime))]
        None => []
      }
    MemoryWarning => [MemoryWarning]
    Destroy => [Destroy]
  }
}

///|
fn embedded_pointer_moved(
  x : Double,
  y : Double,
) -> @embedded_dispatch.EmbeddedDispatchCommand {
  WindowEvent(
    PointerMoved(
      None,
      PhysicalPositionF64(x, y),
      true,
      Touch(@core.FingerId::from_raw(0), None),
    ),
  )
}

///|
fn embedded_pointer_button(
  pressed : Bool,
  x : Double,
  y : Double,
) -> @embedded_dispatch.EmbeddedDispatchCommand {
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
}

///|
fn ime_event_to_window_ime(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> @core.Ime? {
  match kind {
    1 => Some(Commit(text))
    2 => Some(Preedit(text, Some(ImeCursorRange(start, end))))
    3 => Some(Commit(""))
    4 => Some(Preedit("", Some(ImeCursorRange(start, end))))
    5 => Some(DeleteSurrounding(start, end))
    _ => None
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
fn host_default_window_metrics() -> (Int, Int, Double, UInt64, UInt64) {
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
