#import <AppKit/AppKit.h>
#import <moonbit.h>
#import <stdint.h>

static NSEvent *mbw_moui_macos_smoke_mouse_event(NSView *view, NSEventType type) {
  NSWindow *window = view.window;
  if (window == nil) {
    return nil;
  }
  NSPoint local = NSMakePoint(24.0, 32.0);
  NSPoint location = [view convertPoint:local toView:nil];
  return [NSEvent mouseEventWithType:type
                            location:location
                       modifierFlags:0
                           timestamp:NSProcessInfo.processInfo.systemUptime
                        windowNumber:window.windowNumber
                             context:nil
                         eventNumber:0
                          clickCount:1
                            pressure: type == NSEventTypeLeftMouseDown ? 1.0 : 0.0];
}

static NSEvent *mbw_moui_macos_smoke_key_event(NSView *view, NSEventType type) {
  NSWindow *window = view.window;
  if (window == nil) {
    return nil;
  }
  NSPoint location = [view convertPoint:NSMakePoint(24.0, 32.0) toView:nil];
  return [NSEvent keyEventWithType:type
                          location:location
                     modifierFlags:0
                         timestamp:NSProcessInfo.processInfo.systemUptime
                      windowNumber:window.windowNumber
                           context:nil
                        characters:@"a"
       charactersIgnoringModifiers:@"a"
                         isARepeat:NO
                           keyCode:0];
}

MOONBIT_FFI_EXPORT
int32_t mbw_moui_macos_smoke_send_input(uint64_t raw_view_handle) {
  if (raw_view_handle == 0) {
    return 0;
  }
  NSView *view = (__bridge NSView *)(void *)raw_view_handle;
  if (view == nil || view.window == nil) {
    return 0;
  }

  [view.window makeKeyAndOrderFront:nil];
  [view.window makeFirstResponder:view];

  NSEvent *move = mbw_moui_macos_smoke_mouse_event(view, NSEventTypeMouseMoved);
  if (move != nil && [view respondsToSelector:@selector(mouseMoved:)]) {
    [view mouseMoved:move];
  }

  NSEvent *down = mbw_moui_macos_smoke_mouse_event(view, NSEventTypeLeftMouseDown);
  if (down != nil && [view respondsToSelector:@selector(mouseDown:)]) {
    [view mouseDown:down];
  }

  NSEvent *up = mbw_moui_macos_smoke_mouse_event(view, NSEventTypeLeftMouseUp);
  if (up != nil && [view respondsToSelector:@selector(mouseUp:)]) {
    [view mouseUp:up];
  }

  NSEvent *key_down = mbw_moui_macos_smoke_key_event(view, NSEventTypeKeyDown);
  if (key_down != nil && [view respondsToSelector:@selector(keyDown:)]) {
    [view keyDown:key_down];
  }

  NSEvent *key_up = mbw_moui_macos_smoke_key_event(view, NSEventTypeKeyUp);
  if (key_up != nil && [view respondsToSelector:@selector(keyUp:)]) {
    [view keyUp:key_up];
  }

  return 1;
}
