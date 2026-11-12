///|
/// Shutdown is idempotent and leaves the clock in a state where a bounded wait
/// returns immediately instead of hanging on a missing display link.
test "frame clock shutdown is idempotent and waits are bounded" {
  host_vsync_shutdown()
  host_vsync_shutdown()
  assert_false(host_wait_for_vsync(1))
  assert_eq(host_vsync_display_id(), (0 : UInt32))
}

///|
/// A headless host may refuse to start the clock; a display host may start it.
/// Either way init must not trap, and shutdown must return the process to the
/// stopped state.
test "frame clock init and shutdown tolerate both headless and display hosts" {
  host_vsync_shutdown()
  let started = host_vsync_init_handle(0)
  if started {
    ignore(host_wait_for_vsync(1))
  }
  host_vsync_shutdown()
  assert_false(host_wait_for_vsync(1))
}
