#import <Foundation/Foundation.h>
#import "native_ios_host.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

/* Started from AppDelegate so the MoonBit EventLoop can drain HostCmd. */
int mbw_ios_start_event_loop(void);

@interface MBWHostedView : UIView
@end

@implementation MBWHostedView
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint p = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(0, p.x * scale, p.y * scale, t * 1000.0);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint p = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(1, p.x * scale, p.y * scale, t * 1000.0);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint p = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(2, p.x * scale, p.y * scale, t * 1000.0);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  (void)event;
  UITouch *touch = touches.anyObject;
  CGPoint p = [touch locationInView:self];
  CGFloat scale = self.contentScaleFactor;
  NSTimeInterval t = touch ? touch.timestamp : 0.0;
  mbw_ios_host_on_pointer_phase(3, p.x * scale, p.y * scale, t * 1000.0);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat scale = self.contentScaleFactor;
  CGSize size = self.bounds.size;
  mbw_ios_host_on_surface_resize((int32_t)(size.width * scale),
                                 (int32_t)(size.height * scale), (double)scale);
}
@end

@interface MBWHostedAppDelegate : UIResponder <UIApplicationDelegate>
@property(strong, nonatomic) UIWindow *window;
@property(strong, nonatomic) MBWHostedView *hostedView;
@end

@implementation MBWHostedAppDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  (void)application;
  (void)launchOptions;
  mbw_ios_host_on_start();
  CGRect bounds = [UIScreen mainScreen].bounds;
  self.window = [[UIWindow alloc] initWithFrame:bounds];
  UIViewController *vc = [UIViewController new];
  self.hostedView = [[MBWHostedView alloc] initWithFrame:bounds];
  self.hostedView.backgroundColor = [UIColor blackColor];
  self.hostedView.multipleTouchEnabled = NO;
  CGFloat screenScale = [UIScreen mainScreen].scale;
  if (screenScale <= 0.0) {
    screenScale = 1.0;
  }
  self.hostedView.contentScaleFactor = screenScale;
  vc.view = self.hostedView;
  self.window.rootViewController = vc;
  [self.window makeKeyAndVisible];
  CGFloat scale = self.hostedView.contentScaleFactor;
  CGSize size = self.hostedView.bounds.size;
  mbw_ios_host_on_surface_init((uint64_t)(uintptr_t)(__bridge void *)self.hostedView,
                               (uint64_t)(uintptr_t)(__bridge void *)self.window,
                               (int32_t)(size.width * scale),
                               (int32_t)(size.height * scale), (double)scale);
  mbw_ios_host_on_resume();
  (void)mbw_ios_start_event_loop();
  return YES;
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
#endif /* TARGET_OS_IPHONE */
