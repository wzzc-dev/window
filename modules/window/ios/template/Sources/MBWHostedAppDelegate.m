#import "MBWHostedAppDelegate.h"

#include <stdint.h>

#import <moonbit.h>
#import "native_ios_host.h"

int mbw_ios_start_event_loop(void);

@interface MBWHostedView : UIView
@end

@implementation MBWHostedView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint point = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(0, point.x * scale, point.y * scale, t * 1000.0);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint point = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(1, point.x * scale, point.y * scale, t * 1000.0);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint point = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(2, point.x * scale, point.y * scale, t * 1000.0);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint point = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(3, point.x * scale, point.y * scale, t * 1000.0);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat scale = self.contentScaleFactor;
  CGSize size = self.bounds.size;
  mbw_ios_host_on_surface_resize(
      (int32_t)(size.width * scale),
      (int32_t)(size.height * scale),
      (double)scale);
}

@end

@interface MBWHostedTextInputProxy : UITextView
@property(nonatomic, assign) BOOL suppressNotify;
@property(nonatomic, weak) UIView *coordinateContainer;
@property(nonatomic, assign) CGRect candidateRectInContainer;
@end

@implementation MBWHostedTextInputProxy

- (CGRect)firstRectForRange:(UITextRange *)range {
  (void)range;
  if (!CGRectIsEmpty(self.candidateRectInContainer) && self.coordinateContainer) {
    return self.candidateRectInContainer;
  }
  return CGRectZero;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  if (action == @selector(copy:)) return YES;
  if (action == @selector(cut:)) return YES;
  if (action == @selector(paste:)) return YES;
  return [super canPerformAction:action withSender:sender];
}

- (void)copy:(id)sender {
  (void)sender;
  mbw_ios_host_on_ime_event(0, "", 0, 0);
}

- (void)cut:(id)sender {
  (void)sender;
  mbw_ios_host_on_ime_event(1, "", 0, 0);
}

- (void)paste:(id)sender {
  (void)sender;
  // Defer to UITextView paste; the resulting text change is reported through
  // textViewDidChange.
  [super paste:sender];
}

@end

@interface MBWHostedIMEAdapter : NSObject <UITextViewDelegate>
@property(nonatomic, strong) MBWHostedTextInputProxy *proxy;
@property(nonatomic, assign, getter=isApplyingUpdate) BOOL applyingUpdate;
@property(nonatomic, copy) NSString *committedText;
@property(nonatomic, assign) BOOL composing;
- (instancetype)initWithContainer:(UIView *)container;
- (void)applyEnabled:(BOOL)enabled
                text:(NSString *)text
        selLocation:(NSInteger)location
          selLength:(NSInteger)length
       caretOriginX:(double)caretX
       caretOriginY:(double)caretY
       caretWidth:(double)caretW
      caretHeight:(double)caretH;
- (void)reset;
@end

@implementation MBWHostedIMEAdapter

- (instancetype)initWithContainer:(UIView *)container {
  self = [super init];
  if (self != nil) {
    _proxy = [[MBWHostedTextInputProxy alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    _proxy.delegate = self;
    _proxy.autocorrectionType = UITextAutocorrectionTypeDefault;
    _proxy.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    _proxy.backgroundColor = [UIColor clearColor];
    _proxy.alpha = 0.01;
    _proxy.userInteractionEnabled = NO;
    _proxy.coordinateContainer = container;
    [container addSubview:_proxy];
    _committedText = @"";
  }
  return self;
}

- (void)applyEnabled:(BOOL)enabled
                text:(NSString *)text
        selLocation:(NSInteger)location
          selLength:(NSInteger)length
       caretOriginX:(double)caretX
       caretOriginY:(double)caretY
       caretWidth:(double)caretW
      caretHeight:(double)caretH {
  self.applyingUpdate = YES;
  self.committedText = text;
  if (![self.proxy.text isEqualToString:text]) {
    self.proxy.text = text;
  }
  NSInteger utf16Count = self.proxy.text.length;
  NSInteger lower = MAX(0, MIN(location, utf16Count));
  NSInteger upper = MAX(lower, MIN(location + length, utf16Count));
  self.proxy.selectedRange = NSMakeRange((NSUInteger)lower, (NSUInteger)(upper - lower));
  self.proxy.candidateRectInContainer = CGRectMake(caretX, caretY, caretW, caretH);
  self.proxy.userInteractionEnabled = enabled;
  self.applyingUpdate = NO;
  if (enabled) {
    [self.proxy becomeFirstResponder];
  } else {
    self.composing = NO;
    [self.proxy resignFirstResponder];
  }
}

- (void)reset {
  self.applyingUpdate = YES;
  [self.proxy resignFirstResponder];
  self.proxy.text = @"";
  self.proxy.selectedRange = NSMakeRange(0, 0);
  self.proxy.candidateRectInContainer = CGRectZero;
  self.proxy.userInteractionEnabled = NO;
  self.committedText = @"";
  self.composing = NO;
  self.applyingUpdate = NO;
}

- (void)textViewDidChange:(UITextView *)textView {
  if (self.isApplyingUpdate) { return; }
  UITextRange *marked = textView.markedTextRange;
  if (marked != nil) {
    // Composition in progress: forward the marked text as a preedit update.
    // The runtime models this as CompositionUpdate; cursor is the marked range.
    if (!self.composing) {
      self.composing = YES;
    }
    NSString *markedText = [textView textInRange:marked] ?: @"";
    NSInteger len = (NSInteger)markedText.length;
    mbw_ios_host_on_ime_event(2, [markedText UTF8String], (int32_t)len, (int32_t)len);
  } else {
    // Non-composing (ordinary key / delete / paste). Forward only the
    // incremental difference between the previous committed text and the
    // current text, never `textView.text` itself: the runtime owns its own
    // model and treats `Commit(s)` as "insert s at the caret", so sending the
    // full text would re-insert everything on every keystroke and would
    // bury backspace events (the shortened text would be committed in,
    // restoring what the user just deleted).
    NSString *full = textView.text ?: @"";
    NSString *prev = self.committedText ?: @"";
    NSInteger prevLen = (NSInteger)prev.length;
    NSInteger fullLen = (NSInteger)full.length;
    if (self.composing) {
      // A composition just finalized. Send the just-committed segment (the
      // last marked text) as a Commit so the runtime promotes it from
      // preedit to committed text, then fall through to sync any incremental
      // edit afterwards.
      mbw_ios_host_on_ime_event(3, "", 0, 0);
      self.composing = NO;
    }
    if (fullLen >= prevLen && [full hasPrefix:prev]) {
      // Pure suffix insertion (typical keystroke / paste at end-of-text).
      NSString *suffix = [full substringFromIndex:(NSUInteger)prevLen];
      if (suffix.length > 0) {
        mbw_ios_host_on_ime_event(1, [suffix UTF8String], 0, 0);
      }
    } else if (prevLen >= fullLen && [prev hasPrefix:full]) {
      // Pure suffix deletion (backspace at end-of-text). `DeleteSurrounding`
      // semantics: delete `deleted` characters immediately preceding the
      // caret (before=deleted, after=0).
      NSInteger deleted = prevLen - fullLen;
      if (deleted > 0) {
        mbw_ios_host_on_ime_event(5, "", (int32_t)deleted, 0);
      }
    } else {
      // Complex edit (mid-text paste / replace / selection-cut). Cannot be
      // expressed by Commit/DeleteSurrounding alone without a ReplaceAll
      // channel; emit the safest fallback — backspace to clear, then commit
      // the new full text. We do this only when actually needed to avoid the
      // second-keystroke double-up.
      mbw_ios_host_on_ime_event(5, "", (int32_t)prevLen, 0);
      mbw_ios_host_on_ime_event(1, [full UTF8String], 0, 0);
    }
    self.committedText = full;
  }
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  if (self.isApplyingUpdate) { return; }
  if (textView.markedTextRange != nil) { return; }
  NSRange r = textView.selectedRange;
  mbw_ios_host_on_ime_event(4, "", (int32_t)r.location, (int32_t)NSMaxRange(r));
}

@end

@interface MBWHostedAppDelegate ()
@property(strong, nonatomic) MBWHostedView *hostedView;
@property(strong, nonatomic) MBWHostedIMEAdapter *imeAdapter;
@property(strong, nonatomic) UIPanGestureRecognizer *panRecognizer;
@end

// Singleton bridge for backend -> AppDelegate IME apply state calls.
static MBWHostedIMEAdapter *g_ime_adapter = nil;

static void mbw_ios_ime_adapter_set_state(int32_t enabled,
                                          const char *text,
                                          int32_t sel_location,
                                          int32_t sel_length,
                                          double caret_x,
                                          double caret_y,
                                          double caret_w,
                                          double caret_h) {
  NSString *str = text ? [NSString stringWithUTF8String:text] : @"";
  MBWHostedIMEAdapter *adapter = g_ime_adapter;
  dispatch_async(dispatch_get_main_queue(), ^{
    [adapter applyEnabled:(enabled != 0)
                     text:str
             selLocation:sel_location
               selLength:sel_length
            caretOriginX:caret_x
            caretOriginY:caret_y
              caretWidth:caret_w
             caretHeight:caret_h];
  });
}

static void mbw_ios_ime_adapter_reset(void) {
  MBWHostedIMEAdapter *adapter = g_ime_adapter;
  dispatch_async(dispatch_get_main_queue(), ^{
    [adapter reset];
  });
}

@implementation MBWHostedAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  (void)application;
  (void)launchOptions;

  mbw_ios_host_on_start();
  CGRect bounds = UIScreen.mainScreen.bounds;
  self.window = [[UIWindow alloc] initWithFrame:bounds];
  UIViewController *viewController = [UIViewController new];
  self.hostedView = [[MBWHostedView alloc] initWithFrame:bounds];
  self.hostedView.backgroundColor = UIColor.blackColor;
  self.hostedView.multipleTouchEnabled = NO;
  // UIView defaults contentScaleFactor=1; physical surface metrics need the
  // screen scale so Skia raster/GPU frames match device pixels.
  CGFloat screenScale = UIScreen.mainScreen.scale;
  if (screenScale <= 0.0) {
    screenScale = 1.0;
  }
  self.hostedView.contentScaleFactor = screenScale;
  viewController.view = self.hostedView;
  self.window.rootViewController = viewController;
  [self.window makeKeyAndVisible];
  [_hostedView setNeedsLayout];
  [_hostedView layoutIfNeeded];

  // IME adapter holds a hidden UITextView to drive the system keyboard.
  self.imeAdapter = [[MBWHostedIMEAdapter alloc] initWithContainer:self.hostedView];
  g_ime_adapter = self.imeAdapter;
  mbw_ios_ime_install_callbacks(mbw_ios_ime_adapter_set_state,
                                mbw_ios_ime_adapter_reset);

  // Pan gesture drives scroll for MoUI scroll views.
  self.panRecognizer =
      [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
  self.panRecognizer.cancelsTouchesInView = NO;
  [self.hostedView addGestureRecognizer:self.panRecognizer];

  CGFloat scale = self.hostedView.contentScaleFactor;
  CGSize size = self.hostedView.bounds.size;
  mbw_ios_host_on_surface_init(
      (uint64_t)(uintptr_t)(__bridge void *)self.hostedView,
      (uint64_t)(uintptr_t)(__bridge void *)self.window,
      (int32_t)(size.width * scale),
      (int32_t)(size.height * scale),
      (double)scale);
  mbw_ios_host_on_resume();
  (void)mbw_ios_start_event_loop();
  return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
  UIView *view = self.hostedView;
  if (view == nil) { return; }
  CGFloat scale = view.contentScaleFactor;
  CGPoint location = [recognizer locationInView:view];
  CGPoint translation = [recognizer translationInView:view];
  int32_t phase;
  switch (recognizer.state) {
    case UIGestureRecognizerStateBegan: phase = 0; break;
    case UIGestureRecognizerStateChanged: phase = 1; break;
    case UIGestureRecognizerStateEnded: phase = 2; break;
    case UIGestureRecognizerStateCancelled:
    default: phase = 3; break;
  }
  mbw_ios_host_on_scroll(
      location.x * scale,
      location.y * scale,
      translation.x * scale,
      translation.y * scale,
      phase);
  [recognizer setTranslation:CGPointZero inView:view];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  (void)application;
  mbw_ios_host_on_resume();
}

- (void)applicationWillResignActive:(UIApplication *)application {
  (void)application;
  mbw_ios_host_on_pause();
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  (void)application;
  mbw_ios_host_on_surface_term();
  mbw_ios_host_on_stop();
}

- (void)applicationWillTerminate:(UIApplication *)application {
  (void)application;
  mbw_ios_host_on_destroy();
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
  (void)application;
  mbw_ios_host_on_memory_warning();
}

@end
