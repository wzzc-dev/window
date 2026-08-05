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
  KeyboardText(String)
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
  embedded_dispatch_kernel.val.push(host_command_to_embedded(cmd))
}

///|
fn host_command_to_embedded(
  cmd : HostCmd,
) -> @embedded_dispatch.EmbeddedDispatchCommand {
  match cmd {
    Start => @embedded_dispatch.EmbeddedDispatchCommand::Start
    Resume => @embedded_dispatch.EmbeddedDispatchCommand::Resume
    Pause => @embedded_dispatch.EmbeddedDispatchCommand::Pause
    Stop => @embedded_dispatch.EmbeddedDispatchCommand::Stop
    SurfaceInit(handle, token, width, height, scale_factor) =>
      @embedded_dispatch.EmbeddedDispatchCommand::SurfaceInit(
        handle, token, width, height, scale_factor,
      )
    SurfaceTerm => @embedded_dispatch.EmbeddedDispatchCommand::SurfaceTerm
    SurfaceResize(width, height, scale_factor) =>
      @embedded_dispatch.EmbeddedDispatchCommand::SurfaceResize(
        width, height, scale_factor,
      )
    PointerMoved(x, y) =>
      @embedded_dispatch.EmbeddedDispatchCommand::WindowEvent(
        @core.WindowEvent::PointerMoved(
          None,
          @dpi.PhysicalPositionF64::PhysicalPositionF64(x, y),
          true,
          @core.PointerSource::Touch(@core.FingerId::from_raw(0), None),
        ),
      )
    PointerButton(pressed, x, y) =>
      @embedded_dispatch.EmbeddedDispatchCommand::WindowEvent(
        @core.WindowEvent::PointerButton(
          None,
          if pressed {
            @core.ElementState::Pressed
          } else {
            @core.ElementState::Released
          },
          @dpi.PhysicalPositionF64::PhysicalPositionF64(x, y),
          true,
          @core.ButtonSource::Touch(@core.FingerId::from_raw(0), None),
        ),
      )
    KeyboardText(text) =>
      @embedded_dispatch.EmbeddedDispatchCommand::WindowEvent(
        @core.WindowEvent::Ime(@core.Ime::Commit(text)),
      )
    MemoryWarning => @embedded_dispatch.EmbeddedDispatchCommand::MemoryWarning
    Destroy => @embedded_dispatch.EmbeddedDispatchCommand::Destroy
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
      @core.WindowEvent::SurfaceResized(surface.physical_size),
    )
    app_state_queue_window_event(
      @core.WindowId::from_raw(entry.raw_id),
      @core.WindowEvent::ScaleFactorChanged(
        surface.scale_factor,
        @core.SurfaceSizeWriter::SurfaceSizeWriter(surface.physical_size),
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
    @embedded_dispatch.EmbeddedDispatchEffect::Resumed => {
      app_state_queue_lifecycle(DeferredCallback::Resumed)
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::CanCreateSurfaces => {
      app_state_queue_lifecycle(DeferredCallback::CanCreateSurfaces)
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::SurfaceChanged(surface) => {
      host_apply_surface_to_windows(surface)
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::SurfaceInvalidated => {
      host_invalidate_window_handles()
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::DestroySurfaces => {
      app_state_queue_lifecycle(DeferredCallback::DestroySurfaces)
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::Suspended => {
      app_state_queue_lifecycle(DeferredCallback::Suspended)
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::WindowEvent(event) => {
      for entry in app_state_runtime.val.window_entries {
        app_state_queue_window_event(
          @core.WindowId::from_raw(entry.raw_id),
          event,
        )
        break
      }
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::MemoryWarning => {
      app_state_queue_lifecycle(DeferredCallback::MemoryWarning)
      false
    }
    @embedded_dispatch.EmbeddedDispatchEffect::Exit(code) => {
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
