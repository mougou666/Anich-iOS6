#import "DanmakuView.h"
@implementation DItem
@synthesize text = _text;
@synthesize color = _color;
@synthesize time = _time;
@synthesize type = _type;
@end
@interface DanmakuView ()
@property (nonatomic, strong) NSMutableArray *q, *act, *rows;
@property (nonatomic, assign) double t;
@property (nonatomic, assign) CGFloat rh;
- (void)rb;
- (void)spawn:(DItem *)it;
- (NSInteger)fr;
- (void)rm:(UILabel *)l;
@end
@implementation DanmakuView
@synthesize paused = _paused;
@synthesize q = _q;
@synthesize act = _act;
@synthesize rows = _rows;
@synthesize t = _t;
@synthesize rh = _rh;
- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        _q = [NSMutableArray array];
        _act = [NSMutableArray array];
        _rh = 24;
        _rows = [NSMutableArray array];
        [self rb];
    }
    return self;
}
- (void)rb {
    [_rows removeAllObjects];
    NSInteger n = (NSInteger)(self.bounds.size.height / _rh);
    if (n < 1) n = 1;
    for (NSInteger i = 0; i < n; i++) [_rows addObject:[NSNumber numberWithDouble:0]];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self rb];
}
- (void)addItems:(NSArray *)i { if (i) [_q addObjectsFromArray:i]; }
- (void)clear {
    [_q removeAllObjects];
    for (UIView *v in _act) [v removeFromSuperview];
    [_act removeAllObjects];
    [self rb];
}
- (void)tickTo:(double)s {
    _t = s;
    if (_paused) return;
    NSMutableArray *r = [NSMutableArray array];
    for (DItem *i in _q) if (i.time <= s) [r addObject:i];
    for (DItem *i in r) { [self spawn:i]; [_q removeObject:i]; }
}
- (void)spawn:(DItem *)it {
    UILabel *l = [[UILabel alloc] init];
    l.text = it.text;
    l.textColor = it.color ? it.color : [UIColor whiteColor];
    l.font = [UIFont boldSystemFontOfSize:16];
    l.backgroundColor = [UIColor clearColor];
    l.shadowColor = [UIColor blackColor];
    l.shadowOffset = CGSizeMake(1, 1);
    l.numberOfLines = 1;
    [l sizeToFit];
    CGFloat w = l.bounds.size.width;
    CGFloat h = _rh;
    CGFloat vw = self.bounds.size.width;
    CGFloat vh = self.bounds.size.height;
    if (it.type == 5) {
        NSInteger r = [self fr];
        if (r < 0) return;
        l.frame = CGRectMake((vw - w) / 2, r * h, w, h);
        [self addSubview:l];
        [_act addObject:l];
        [self performSelector:@selector(rm:) withObject:l afterDelay:3.0];
    } else if (it.type == 4) {
        NSInteger r = (NSInteger)_rows.count - 1;
        if (r < 0) return;
        l.frame = CGRectMake((vw - w) / 2, vh - r * h - h, w, h);
        [self addSubview:l];
        [_act addObject:l];
        [self performSelector:@selector(rm:) withObject:l afterDelay:3.0];
    } else {
        NSInteger r = [self fr];
        if (r < 0) return;
        l.frame = CGRectMake(vw, r * h, w, h);
        [self addSubview:l];
        [_act addObject:l];
        CGFloat dist = vw + w;
        NSTimeInterval dur = 10.0;
        [UIView animateWithDuration:dur delay:0 options:UIViewAnimationOptionCurveLinear
                         animations:^{
                             CGRect f = l.frame;
                             f.origin.x = -w;
                             l.frame = f;
                         } completion:^(BOOL ok) {
                             [l removeFromSuperview];
                             [_act removeObject:l];
                         }];
        double e = _t + dur * (w / dist) + 0.2;
        [_rows replaceObjectAtIndex:(NSUInteger)r withObject:[NSNumber numberWithDouble:e]];
    }
}
- (NSInteger)fr {
    NSInteger c = (NSInteger)_rows.count;
    for (NSInteger i = 0; i < c; i++) {
        double e = [[_rows objectAtIndex:(NSUInteger)i] doubleValue];
        if (e <= _t) {
            if (_t > 0) [_rows replaceObjectAtIndex:(NSUInteger)i withObject:[NSNumber numberWithDouble:_t + 3.0]];
            return i;
        }
    }
    return -1;
}
- (void)rm:(UILabel *)l {
    [l removeFromSuperview];
    [_act removeObject:l];
}
@end