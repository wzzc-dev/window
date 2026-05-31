///|
fn primary_monitor_for_test() -> @core.MonitorHandle? {
  primary_monitor()
}

///|
test "uuid_stable" {
  let primary_id = cg_main_display_id()
  assert_true(primary_id > (0 : Int).to_uint64())

  let handle_a = monitor_from_native_id(primary_id)
  let handle_b = monitor_from_native_id(primary_id)
  match handle_a {
    Some(handle_a) =>
      match handle_b {
        Some(handle_b) => {
          assert_eq(handle_a, handle_b)
          assert_eq(handle_a.native_id(), handle_b.native_id())
        }
        None => ()
      }
    None => ()
  }

  let handle_c = primary_monitor_for_test()
  let handle_d = primary_monitor_for_test()
  match handle_c {
    Some(handle_c) =>
      match handle_d {
        Some(handle_d) => {
          assert_eq(handle_c, handle_d)
          assert_eq(handle_c.native_id(), handle_d.native_id())
        }
        None => ()
      }
    None => ()
  }
}

///|
test "monitorhandle_from_zero" {
  let primary_id = cg_main_display_id()
  assert_true(primary_id > (0 : Int).to_uint64())

  let handle0 = monitor_from_native_id((0 : Int).to_uint64())
  let handle1 = monitor_from_native_id(primary_id)
  match handle0 {
    Some(handle0) =>
      match handle1 {
        Some(handle1) => {
          assert_eq(handle0, handle1)
          assert_eq(handle0.native_id(), handle1.native_id())
        }
        None => ()
      }
    None => ()
  }
}

///|
test "from_invalid_id" {
  assert_true(monitor_from_native_id((10000 : Int).to_uint64()) == None)
}

///|
test "invalid_monitor_handle" {
  assert_true(monitor_from_native_id((10000 : Int).to_uint64()) == None)
}

///|
test "primary_monitor_has_ns_screen_handle" {
  let monitor = primary_monitor_for_test()
  match monitor {
    Some(monitor) => assert_true(monitor_ns_screen(monitor) is Some(_))
    None => ()
  }
}

///|
test "available_monitors_allows_empty_headless_result" {
  let monitors = available_monitors()
  match primary_monitor_for_test() {
    Some(primary) => assert_true(monitors.any(monitor => monitor == primary))
    None => assert_true(monitors.is_empty())
  }
}
