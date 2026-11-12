///|
test "accent argb packing clamps channels and keeps ARGB order" {
  assert_true(accent_argb_from_components(1.0, 0.0, 0.0) == 0xFFFF0000U)
  assert_true(accent_argb_from_components(0.0, 1.0, 0.0, a=0.5) == 0x8000FF00U)
  assert_true(accent_argb_from_components(2.0, -1.0, 0.5) == 0xFFFF0080U)
}
