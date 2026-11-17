#import <UIKit/UIKit.h>
#import "MainVC.h"
@interface AppDelegate : UIResponder <UIApplicationDelegate> @property (nonatomic,strong) UIWindow *window; @end
@implementation AppDelegate
@synthesize window=_window;
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o {
    self.window=[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController=[[MainVC alloc] init];
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int c,char**v){@autoreleasepool{return UIApplicationMain(c,v,nil,NSStringFromClass([AppDelegate class]));}}