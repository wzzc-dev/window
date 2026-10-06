///|
// Application icon (Dock + About panel) entry points. macOS keeps one
// application-wide icon: `NSApplication.applicationIconImage` drives the Dock
// tile for unbundled binaries and overrides the bundle icon when set, so the
// API lives on the application rather than on a window.

///|
/// Whether the process runs from a bundled `.app` (an Info.plist-backed
/// bundle). Bundled apps derive their Dock icon from the bundle resources,
/// while unbundled binaries (e.g. `moon run` output) show the generic system
/// icon until an application icon is set.
pub fn application_is_bundled() -> Bool {
  native_application_is_bundled()
}

///|
/// Set the application icon shown in the Dock (and the About panel) from an
/// image file path. Must be called on the main thread. Returns false when
/// AppKit is unavailable or the file cannot be decoded; the previous icon is
/// kept in that case.
pub fn set_application_icon_path(path : String) -> Bool {
  let app = native_application_shared_handle()
  if app == (0 : Int).to_uint64() {
    return false
  }
  let path_string = objc_nsstring_from_string(path)
  if path_string == (0 : Int).to_uint64() {
    return false
  }
  let image_class = objc_runtime_class_handle("NSImage")
  if image_class == (0 : Int).to_uint64() {
    return false
  }
  let allocated = appkit_objc_msg_send_u64(
    image_class,
    objc_runtime_selector_handle("alloc"),
  )
  if allocated == (0 : Int).to_uint64() {
    return false
  }
  let image = appkit_objc_msg_send_u64_u64(
    allocated,
    objc_runtime_selector_handle("initWithContentsOfFile:"),
    path_string,
  )
  if image == (0 : Int).to_uint64() {
    // A failed `initWith...` releases the allocation it consumed, so there is
    // nothing left to release here.
    return false
  }
  appkit_objc_msg_send_void_u64(
    app,
    objc_runtime_selector_handle("setApplicationIconImage:"),
    image,
  )
  appkit_objc_release_raw_object(image)
  true
}

///|
/// Set the application icon shown in the Dock (and the About panel) from
/// encoded image data (PNG, JPEG, TIFF — anything `NSImage` decodes). Must be
/// called on the main thread. Returns false when AppKit is unavailable or the
/// data cannot be decoded; the previous icon is kept in that case.
pub fn set_application_icon_data(data : Bytes) -> Bool {
  data.length() > 0 && native_application_set_icon_data(data, data.length())
}

///|
#borrow(data)
extern "C" fn native_application_set_icon_data(
  data : Bytes,
  data_len : Int,
) -> Bool = "mbw_appkit_set_application_icon_data"
