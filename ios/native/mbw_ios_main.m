#import <UIKit/UIKit.h>

@interface MBWHostedAppDelegate : UIResponder <UIApplicationDelegate>
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([MBWHostedAppDelegate class]));
  }
}
