// native_appkit_menu.m — System menu bar support for macOS.
// Creates an ObjC target object that receives menu item actions and dispatches
// them to MoonBit via a trampoline callback.

#import "native_appkit_bridge.h"
#import <objc/runtime.h>

// Trampoline for menu action dispatch.
static mbw_menu_action_trampoline_t g_menu_action_trampoline = NULL;
static void *g_menu_action_closure = NULL;

// The singleton target object that receives menu item actions.
static id g_menu_action_target = nil;

// Action ID stored as an associated object key.
static const char kMouiMenuActionIdKey;

// ---------------------------------------------------------------------------
// MouiMenuActionTarget — dynamically created NSObject subclass
// ---------------------------------------------------------------------------

@interface MouiMenuActionTarget : NSObject
- (void)handleMenuAction:(id)sender;
@end

@implementation MouiMenuActionTarget

- (void)handleMenuAction:(id)sender {
  if (g_menu_action_trampoline == NULL || g_menu_action_closure == NULL) {
    return;
  }
  NSNumber *actionId = objc_getAssociatedObject(sender, &kMouiMenuActionIdKey);
  int32_t action_id = actionId ? [actionId intValue] : -1;
  void *closure = g_menu_action_closure;
  moonbit_incref(closure);
  g_menu_action_trampoline(closure, action_id);
  moonbit_decref(closure);
}

@end

// ---------------------------------------------------------------------------
// Public API called from MoonBit
// ---------------------------------------------------------------------------

MOONBIT_FFI_EXPORT
void mbw_install_menu_action_callback(mbw_menu_action_trampoline_t trampoline, void *closure) {
  if (g_menu_action_closure != NULL) {
    moonbit_decref(g_menu_action_closure);
  }
  g_menu_action_trampoline = trampoline;
  g_menu_action_closure = closure;
}

// Returns a retained reference to the singleton MouiMenuActionTarget.
MOONBIT_FFI_EXPORT
uint64_t mbw_create_menu_action_target(void) {
  if (g_menu_action_target == nil) {
    g_menu_action_target = [[MouiMenuActionTarget alloc] init];
  }
  return (uint64_t)(uintptr_t)g_menu_action_target;
}

// Sets the action ID (associated object) on an NSMenuItem.
MOONBIT_FFI_EXPORT
void mbw_set_menu_item_action_id(uint64_t item_handle, int32_t action_id) {
  id item = (__bridge id)(void *)item_handle;
  objc_setAssociatedObject(item, &kMouiMenuActionIdKey,
                           @(action_id), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
