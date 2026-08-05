///|
/// Raw surface payload forwarded by the physical embedder. No generation is
/// created here; MoUI's window-host owner assigns logical generations when it
/// consumes this callback.
pub(all) struct EmbeddedDispatchSurface {
  handle : UInt64
  token : UInt64
  physical_size : @dpi.PhysicalSize
  scale_factor : Double
} derive(Eq, Debug)

///|
/// Platform-decoded commands accepted by the physical callback adapter.
pub(all) enum EmbeddedDispatchCommand {
  Start
  Resume
  Pause
  Stop
  SurfaceInit(UInt64, UInt64, Int, Int, Double)
  SurfaceTerm
  SurfaceResize(Int, Int, Double)
  WindowEvent(@core.WindowEvent)
  MemoryWarning
  Destroy
}

///|
/// Ordered physical effects. Lifecycle decisions, primary-window routing,
/// stale-generation rejection, and application exit intent are handled by
/// the MoUI window-host coordinator after these effects are delivered.
pub(all) enum EmbeddedDispatchEffect {
  Resumed
  CanCreateSurfaces
  SurfaceChanged(EmbeddedDispatchSurface)
  SurfaceInvalidated
  DestroySurfaces
  Suspended
  WindowEvent(@core.WindowEvent)
  MemoryWarning
  Exit(Int)
}

///|
/// Physical FIFO only. It intentionally has no lifecycle, surface, window,
/// or exit fields; the native queue and OS callback order remain the only
/// physical source of truth.
pub struct EmbeddedDispatchQueue {
  mut pending : Array[EmbeddedDispatchCommand]
  mut surface : EmbeddedDispatchSurface?
}

///|
pub fn EmbeddedDispatchQueue::new() -> EmbeddedDispatchQueue {
  { pending: [], surface: None }
}

///|
pub fn EmbeddedDispatchQueue::push(
  self : EmbeddedDispatchQueue,
  command : EmbeddedDispatchCommand,
) -> Unit {
  self.pending.push(command)
}

///|
pub fn EmbeddedDispatchQueue::drain(
  self : EmbeddedDispatchQueue,
) -> Array[EmbeddedDispatchEffect] {
  let commands = self.pending
  self.pending = []
  let effects : Array[EmbeddedDispatchEffect] = []
  for command in commands {
    match command {
      SurfaceInit(handle, token, width, height, scale_factor) =>
        self.surface = Some({
          handle,
          token,
          physical_size: normalized_size(width, height),
          scale_factor: normalized_scale(scale_factor, fallback=1.0),
        })
      SurfaceTerm => self.surface = None
      SurfaceResize(width, height, scale_factor) =>
        match self.surface {
          Some(current) =>
            self.surface = Some({
              ..current,
              physical_size: normalized_size(width, height),
              scale_factor: normalized_scale(
                scale_factor,
                fallback=current.scale_factor,
              ),
            })
          None => ()
        }
      _ => ()
    }
    for effect in dispatch_embedded_command(command) {
      effects.push(effect)
    }
  }
  effects
}

///|
pub fn EmbeddedDispatchQueue::surface(
  self : EmbeddedDispatchQueue,
) -> EmbeddedDispatchSurface? {
  self.surface
}

///|
pub fn EmbeddedDispatchQueue::surfaces_allowed(
  self : EmbeddedDispatchQueue,
) -> Bool {
  self.surface is Some(_)
}

///|
fn dispatch_embedded_command(
  command : EmbeddedDispatchCommand,
) -> Array[EmbeddedDispatchEffect] {
  match command {
    Start => []
    Resume => [EmbeddedDispatchEffect::Resumed]
    Pause | Stop =>
      [
        EmbeddedDispatchEffect::DestroySurfaces,
        EmbeddedDispatchEffect::Suspended,
      ]
    SurfaceInit(handle, token, width, height, scale_factor) =>
      [
        EmbeddedDispatchEffect::CanCreateSurfaces,
        EmbeddedDispatchEffect::SurfaceChanged({
          handle,
          token,
          physical_size: normalized_size(width, height),
          scale_factor: normalized_scale(scale_factor, fallback=1.0),
        }),
      ]
    SurfaceTerm =>
      [
        EmbeddedDispatchEffect::SurfaceInvalidated,
        EmbeddedDispatchEffect::DestroySurfaces,
      ]
    SurfaceResize(width, height, scale_factor) =>
      [
        EmbeddedDispatchEffect::SurfaceChanged({
          handle: 0UL,
          token: 0UL,
          physical_size: normalized_size(width, height),
          scale_factor: normalized_scale(scale_factor, fallback=1.0),
        }),
      ]
    WindowEvent(event) => [EmbeddedDispatchEffect::WindowEvent(event)]
    MemoryWarning => [EmbeddedDispatchEffect::MemoryWarning]
    Destroy =>
      [EmbeddedDispatchEffect::DestroySurfaces, EmbeddedDispatchEffect::Exit(0)]
  }
}

///|
fn normalized_size(width : Int, height : Int) -> @dpi.PhysicalSize {
  @dpi.PhysicalSize::PhysicalSize(width.max(1), height.max(1))
}

///|
fn normalized_scale(scale : Double, fallback~ : Double) -> Double {
  if scale > 0.0 {
    scale
  } else {
    fallback
  }
}
