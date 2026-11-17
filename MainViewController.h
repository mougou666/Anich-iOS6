#import <UIKit/UIKit.h>

@interface MainViewController : UIViewController
@end

@interface DetailViewController : UIViewController
@property (nonatomic, assign) NSInteger bid;
@property (nonatomic, copy) NSString *bangumiTitle;
@end