///|
/// Ordered host commands. Production native glue and host-sim tests push the
/// same commands; EventLoop pumps drain them into ApplicationHandler callbacks.
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
} derive(Eq, Debug)

///|
/// Host lifecycle phase tracked for create_window gating and generation.
priv enum HostPhase {
  Idle
  Started
  Resumed
  SurfacesAllowed
  Suspended
} derive(Eq, Debug)

///|
priv struct HostSurfaceSnapshot {
  handle : UInt64
  token : UInt64
  width : Int
  height : Int
  scale_factor : Double
}

///|
priv struct HostRuntime {
  mut phase : HostPhase
  mut surfaces_allowed : Bool
  mut generation : Int
  mut surface : HostSurfaceSnapshot?
  mut pending : Array[HostCmd]
  mut primary_window_id : Int?
}

///|
fn HostRuntime::new() -> HostRuntime {
  {
    phase: Idle,
    surfaces_allowed: false,
    generation: 0,
    surface: None,
    pending: [],
    primary_window_id: None,
  }
}

///|
let host_runtime : Ref[HostRuntime] = Ref(HostRuntime::new())

///|
/// Reset host simulator state between tests.
pub fn host_reset_for_test() -> Unit {
  host_runtime.val = HostRuntime::new()
  app_state_reset_for_test()
  host_reset_native_queue()
}

///|
/// Map iOS host IME event kinds to `window/core::Ime` variants.
/// `MBW_IOS_IME_COMMIT=1`, `PREEDIT=2`, `PREEDIT_END=3`,
/// `SET_SELECTION=4`, `DELETE_BACK=5`.
fn ime_event_to_window_ime(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> @core.Ime? {
  match kind {
    1 => Some(@core.Ime::Commit(text))
    2 =>
      Some(
        @core.Ime::Preedit(
          text,
          Some(@core.ImeCursorRange::ImeCursorRange(start, end)),
        ),
      )
    3 => Some(@core.Ime::Commit(""))
    4 =>
      Some(
        @core.Ime::Preedit(
          "",
          Some(@core.ImeCursorRange::ImeCursorRange(start, end)),
        ),
      )
    5 => Some(@core.Ime::DeleteSurrounding(start, end))
    _ => None
  }
}

///|
/// Push a host command (native bridge or host-sim).
pub fn host_push(cmd : HostCmd) -> Unit {
  host_runtime.val.pending.push(cmd)
}

///|
fn host_surfaces_allowed() -> Bool {
  host_runtime.val.surfaces_allowed
}

///|
fn host_generation() -> Int {
  host_runtime.val.generation
}

///|
fn host_primary_window_id() -> Int? {
  host_runtime.val.primary_window_id
}

///|
fn host_set_primary_window_id(raw_id : Int?) -> Unit {
  host_runtime.val.primary_window_id = raw_id
}

///|
fn host_surface_snapshot() -> HostSurfaceSnapshot? {
  host_runtime.val.surface
}

///|
fn host_bump_generation() -> Int {
  host_runtime.val.generation = host_runtime.val.generation + 1
  host_runtime.val.generation
}

///|
fn host_invalidate_window_handles() -> Unit {
  for entry in app_state_runtime.val.window_entries {
    entry.surface_handle = 0UL
    entry.surface_token = 0UL
    entry.generation = host_runtime.val.generation
  }
}

///|
fn host_apply_surface_to_windows(
  handle : UInt64,
  token : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Unit {
  let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
  let size = platform_nonzero_size(width, height)
  for entry in app_state_runtime.val.window_entries {
    entry.surface_handle = handle
    entry.surface_token = token
    entry.width = size.width
    entry.height = size.height
    entry.scale_factor = scale
    entry.generation = host_runtime.val.generation
    let window_id = @core.WindowId::from_raw(entry.raw_id)
    app_state_queue_window_event(window_id, SurfaceResized(size))
    app_state_queue_window_event(
      window_id,
      ScaleFactorChanged(scale, SurfaceSizeWriter(size)),
    )
    app_state_request_redraw(entry.raw_id)
  }
}

///|
/// Drain host commands into deferred ApplicationHandler callbacks / window events.
/// Returns whether the host requested process/loop exit.
fn host_drain_into_app_state() -> Bool {
  let cmds = host_runtime.val.pending
  host_runtime.val.pending = []
  let mut exit_loop = false
  for cmd in cmds {
    match cmd {
      Start =>
        match host_runtime.val.phase {
          Idle => host_runtime.val.phase = Started
          _ => ()
        }
      Resume => {
        host_runtime.val.phase = Resumed
        app_state_queue_lifecycle(Resumed)
      }
      Pause | Stop => {
        if host_runtime.val.surfaces_allowed {
          host_runtime.val.surfaces_allowed = false
          ignore(host_bump_generation())
          host_invalidate_window_handles()
          app_state_queue_lifecycle(DestroySurfaces)
        }
        host_runtime.val.phase = Suspended
        host_runtime.val.surface = None
        app_state_queue_lifecycle(Suspended)
      }
      SurfaceInit(handle, token, width, height, scale_factor) => {
        ignore(host_bump_generation())
        let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
        let size = platform_nonzero_size(width, height)
        host_runtime.val.surface = Some({
          handle,
          token,
          width: size.width,
          height: size.height,
          scale_factor: scale,
        })
        host_runtime.val.surfaces_allowed = true
        host_runtime.val.phase = SurfacesAllowed
        app_state_queue_lifecycle(CanCreateSurfaces)
        host_apply_surface_to_windows(
          handle,
          token,
          size.width,
          size.height,
          scale,
        )
      }
      SurfaceTerm => {
        if host_runtime.val.surfaces_allowed {
          host_runtime.val.surfaces_allowed = false
          ignore(host_bump_generation())
          host_invalidate_window_handles()
          app_state_queue_lifecycle(DestroySurfaces)
        }
        host_runtime.val.surface = None
        match host_runtime.val.phase {
          SurfacesAllowed | Resumed => host_runtime.val.phase = Resumed
          _ => ()
        }
      }
      SurfaceResize(width, height, scale_factor) =>
        match host_runtime.val.surface {
          Some(surface) => {
            let scale = if scale_factor > 0.0 {
              scale_factor
            } else {
              surface.scale_factor
            }
            let size = platform_nonzero_size(width, height)
            host_runtime.val.surface = Some({
              handle: surface.handle,
              token: surface.token,
              width: size.width,
              height: size.height,
              scale_factor: scale,
            })
            host_apply_surface_to_windows(
              surface.handle,
              surface.token,
              size.width,
              size.height,
              scale,
            )
          }
          None => ()
        }
      PointerMoved(x, y) =>
        match host_primary_window_id() {
          Some(raw_id) => {
            let window_id = @core.WindowId::from_raw(raw_id)
            let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(x, y)
            app_state_queue_window_event(
              window_id,
              PointerMoved(
                None,
                position,
                true,
                Touch(@core.FingerId::from_raw(0), None),
              ),
            )
          }
          None => ()
        }
      PointerButton(pressed, x, y) =>
        match host_primary_window_id() {
          Some(raw_id) => {
            let window_id = @core.WindowId::from_raw(raw_id)
            let state = if pressed {
              @core.ElementState::Pressed
            } else {
              @core.ElementState::Released
            }
            let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(x, y)
            app_state_queue_window_event(
              window_id,
              PointerButton(
                None,
                state,
                position,
                true,
                Touch(@core.FingerId::from_raw(0), None),
              ),
            )
          }
          None => ()
        }
      PointerPhase(phase, x, y) =>
        match host_primary_window_id() {
          Some(raw_id) => {
            let window_id = @core.WindowId::from_raw(raw_id)
            let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(x, y)
            app_state_queue_window_event(
              window_id,
              PointerMoved(
                None,
                position,
                true,
                Touch(@core.FingerId::from_raw(0), None),
              ),
            )
            if phase == 0 {
              app_state_queue_window_event(
                window_id,
                PointerButton(
                  None,
                  @core.ElementState::Pressed,
                  position,
                  true,
                  Touch(@core.FingerId::from_raw(0), None),
                ),
              )
            } else if phase == 2 || phase == 3 {
              app_state_queue_window_event(
                window_id,
                PointerButton(
                  None,
                  @core.ElementState::Released,
                  position,
                  true,
                  Touch(@core.FingerId::from_raw(0), None),
                ),
              )
            }
          }
          None => ()
        }
      Scroll(_, _, dx, dy, phase) =>
        match host_primary_window_id() {
          Some(raw_id) => {
            let window_id = @core.WindowId::from_raw(raw_id)
            let position : @dpi.PhysicalPositionF64 = PhysicalPositionF64(
              dx, dy,
            )
            let phase_enum = match phase {
              0 => @core.TouchPhase::Started
              1 => @core.TouchPhase::Moved
              2 => @core.TouchPhase::Ended
              _ => @core.TouchPhase::Cancelled
            }
            app_state_queue_window_event(
              window_id,
              MouseWheel(
                None,
                @core.MouseScrollDelta::PixelDelta(position),
                phase_enum,
              ),
            )
          }
          None => ()
        }
      KeyboardText(text) =>
        match host_primary_window_id() {
          Some(raw_id) => {
            let window_id = @core.WindowId::from_raw(raw_id)
            app_state_queue_window_event(window_id, Ime(Commit(text)))
          }
          None => ()
        }
      ImeEvent(ime_kind, text, start, end) =>
        match host_primary_window_id() {
          Some(raw_id) => {
            let window_id = @core.WindowId::from_raw(raw_id)
            match ime_event_to_window_ime(ime_kind, text, start, end) {
              Some(ime) => app_state_queue_window_event(window_id, Ime(ime))
              None => ()
            }
          }
          None => ()
        }
      MemoryWarning => app_state_queue_lifecycle(MemoryWarning)
      Destroy => {
        if host_runtime.val.surfaces_allowed {
          host_runtime.val.surfaces_allowed = false
          ignore(host_bump_generation())
          host_invalidate_window_handles()
          app_state_queue_lifecycle(DestroySurfaces)
        }
        host_runtime.val.surface = None
        host_runtime.val.phase = Idle
        app_state_request_exit(0)
        exit_loop = true
      }
    }
  }
  exit_loop
}

///|
/// Host surface metrics for create_window when surfaces are allowed.
fn host_default_window_metrics() -> (Int, Int, Double, UInt64, UInt64) {
  match host_surface_snapshot() {
    Some(surface) =>
      (
        surface.width,
        surface.height,
        surface.scale_factor,
        surface.handle,
        surface.token,
      )
    None => (1, 1, 1.0, 0UL, 0UL)
  }
}
