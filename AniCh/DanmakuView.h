#import <UIKit/UIKit.h>
@interface DItem : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) double time;
@property (nonatomic, assign) int type;
@end
@interface DanmakuView : UIView
@property (nonatomic, assign) BOOL paused;
- (void)addItems:(NSArray *)items;
- (void)clear;
- (void)tickTo:(double)sec;
@end