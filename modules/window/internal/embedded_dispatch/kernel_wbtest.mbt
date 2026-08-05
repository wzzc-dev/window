///|
test "embedded dispatch preserves command order without lifecycle state" {
  let queue = EmbeddedDispatchQueue::new()
  queue.push(Resume)
  queue.push(SurfaceInit(1UL, 2UL, 100, 200, 2.0))
  queue.push(WindowEvent(@core.WindowEvent::RedrawRequested))
  let effects = queue.drain()
  inspect(effects.length(), content="4")
  match effects[0] {
    Resumed => ()
    _ => fail("expected resumed")
  }
  match effects[1] {
    CanCreateSurfaces => ()
    _ => fail("expected can_create_surfaces")
  }
  match effects[3] {
    WindowEvent(@core.WindowEvent::RedrawRequested) => ()
    _ => fail("expected window event")
  }
  inspect(queue.drain().length(), content="0")
}

///|
test "surface replacement and destroy are physical effects only" {
  let queue = EmbeddedDispatchQueue::new()
  queue.push(SurfaceTerm)
  queue.push(Destroy)
  let effects = queue.drain()
  inspect(effects.length(), content="4")
  match effects[0] {
    SurfaceInvalidated => ()
    _ => fail("expected invalidation")
  }
  match effects[1] {
    DestroySurfaces => ()
    _ => fail("expected destroy surfaces")
  }
  match effects[2] {
    DestroySurfaces => ()
    _ => fail("expected destroy surfaces before exit")
  }
  match effects[3] {
    Exit(0) => ()
    _ => fail("expected exit")
  }
}
