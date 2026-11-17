#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import "MainVC.h"
#import "API.h"
#import <MediaPlayer/MediaPlayer.h>

#define UD [NSUserDefaults standardUserDefaults]
static NSString *kTokenKey = @"kToken";
static NSString *kPlayModeKey = @"kPlayMode";
static NSString *kBaseUrlKey = @"kBaseUrl";
static NSString *kPlaySpeedKey = @"kPlaySpeed";

#pragma mark - 配色

static UIColor *Accent(void)   { return [UIColor colorWithRed:79/255.0  green:195/255.0 blue:247/255.0 alpha:1.0]; }
static UIColor *Bg(void)       { return [UIColor colorWithWhite:0.94 alpha:1.0]; }
static UIColor *Card(void)     { return [UIColor whiteColor]; }
static UIColor *TitleC(void)   { return [UIColor colorWithWhite:0.13 alpha:1.0]; }
static UIColor *Subtitle(void) { return [UIColor colorWithWhite:0.55 alpha:1.0]; }
static UIColor *Divider(void)  { return [UIColor colorWithWhite:0.90 alpha:1.0]; }

#pragma mark - 主题图片加载（参考 ACCThemeImage）

static NSMutableDictionary *gImgCache = nil;

static UIImage *FindImage(NSString *name) {
    if (!name.length) return nil;
    if (!gImgCache) gImgCache = [[NSMutableDictionary alloc] init];
    id cached = [gImgCache objectForKey:name];
    if (cached) return (cached == [NSNull null]) ? nil : cached;
    
    NSString *folder = @"luotianyi";
    UIImage *img = nil;
    NSArray *exts = [NSArray arrayWithObjects:@"png", @"jpg", @"jpeg", nil];
    
    // 1. 优先从 Documents/themes/luotianyi/ 读（用户导入的主题）
    NSString *userDir = [NSString stringWithFormat:@"%@/Documents/themes/%@", NSHomeDirectory(), folder];
    for (NSString *ext in exts) {
        NSString *p = [NSString stringWithFormat:@"%@/%@.%@", userDir, name, ext];
        img = [UIImage imageWithContentsOfFile:p];
        if (img) break;
    }
    // 2. 从 Xcode 工程里的 luotianyi 文件夹读（放在 Images.xcassets 或文件夹引用）
    if (!img) {
        for (NSString *ext in exts) {
            img = [UIImage imageNamed:[NSString stringWithFormat:@"%@/%@.%@", folder, name, ext]];
            if (img) break;
        }
    }
    // 3. 直接以 name 找（兼容放在根目录的情况）
    if (!img) {
        for (NSString *ext in exts) {
            img = [UIImage imageNamed:[NSString stringWithFormat:@"%@.%@", name, ext]];
            if (img) break;
        }
    }
    
    if (img) [gImgCache setObject:img forKey:name];
    else [gImgCache setObject:[NSNull null] forKey:name];
    return img;
}

#pragma mark - 自定义顶栏（照参考 ACCMakeTopBar）

static const CGFloat kTopBarH = 44.0f;

static UIView *MakeTopBar(CGFloat w, NSString *title, id target, SEL backAction) {
    UIView *tb = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, kTopBarH)];
    tb.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIImage *bg = FindImage(@"head_bg");
    if (bg) {
        tb.backgroundColor = [UIColor blackColor];
        UIImageView *iv = [[UIImageView alloc] initWithFrame:tb.bounds];
        iv.image = bg;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [tb addSubview:iv];
        UIView *ov = [[UIView alloc] initWithFrame:tb.bounds];
        ov.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25f];
        ov.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [tb addSubview:ov];
    } else {
        tb.backgroundColor = Accent();
    }
    // 返回按钮 "<"
    if (target && backAction) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(0, 0, 44, kTopBarH);
        [b setTitle:@"<" forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [b addTarget:target action:backAction forControlEvents:UIControlEventTouchUpInside];
        [tb addSubview:b];
    }
    // 居中标题
    UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, kTopBarH)];
    lb.backgroundColor = [UIColor clearColor];
    lb.font = [UIFont boldSystemFontOfSize:16];
    lb.textColor = [UIColor whiteColor];
    lb.text = title;
    lb.textAlignment = UITextAlignmentCenter;
    lb.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [tb addSubview:lb];
    return tb;
}

// 表格顶部垫一个 44pt 透明占位：内容永远在顶栏下面，不依赖 contentInset
static UIView *TopSpacerView(CGFloat w) {
    UIView *sp = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, kTopBarH)];
    sp.backgroundColor = [UIColor clearColor];
    sp.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    return sp;
}

static UIView *InstallTopBar(UIViewController *vc, NSString *title, SEL backAction) {
    UIView *bar = MakeTopBar(vc.view.bounds.size.width, title, backAction ? vc : nil, backAction);
    bar.tag = 88991;
    bar.layer.zPosition = 1000;   // 永远压在单元格上面
    [vc.view addSubview:bar];
    [vc.view bringSubviewToFront:bar];
    if ([vc isKindOfClass:[UITableViewController class]]) {
        // 你的 SDK 里没这个属性名，只能用字符串选择器 / KVC，别用点语法
        SEL sel = NSSelectorFromString(@"setAutomaticallyAdjustsScrollViewInsets:");
        if ([vc respondsToSelector:sel]) {
            [vc setValue:[NSNumber numberWithBool:NO] forKey:@"automaticallyAdjustsScrollViewInsets"];
        }
    }
    return bar;
}


static void LayoutTopBar(UIViewController *vc) {
    UIView *bar = [vc.view viewWithTag:88991];
    if (bar) {
        bar.frame = CGRectMake(0, 0, vc.view.bounds.size.width, kTopBarH);
        bar.layer.zPosition = 1000;
        [vc.view bringSubviewToFront:bar];
    }
    if ([vc isKindOfClass:[UITableViewController class]]) {
        UITableView *tv = [(UITableViewController *)vc tableView];
        UIView *hdr = tv.tableHeaderView;
        if (hdr && hdr.frame.size.width != tv.bounds.size.width) {
            CGRect f = hdr.frame;
            f.size.width = tv.bounds.size.width;
            hdr.frame = f;
        }
    }
}

#pragma mark - 横屏容器转发

@interface UINavigationController (ForceRotate) @end
@implementation UINavigationController (ForceRotate)
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }
@end

#pragma mark - 尺寸辅助

static BOOL IsPad(void) {
    static BOOL isPad = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad); });
    return isPad;
}
static CGSize CurrentScreenSize(void) { return [UIScreen mainScreen].bounds.size; }
static CGFloat ListRowHeight(void) {
    CGSize s = CurrentScreenSize();
    if (IsPad()) return (s.width > s.height) ? 140 : 130;
    if (s.width >= 414) return 112;
    if (s.width >= 375) return 106;
    return 100;
}
static CGFloat IntroRowHeight(void) { return IsPad() ? 170 : 130; }
static CGFloat DownloadRowHeight(void) { return IsPad() ? 90 : 80; }
static CGFloat ThumbSize(CGFloat rowH) {
    if (IsPad()) { CGFloat s = rowH - 24; if (s > 130) s = 130; if (s < 80) s = 80; return s; }
    CGFloat s = rowH - 16; if (s > 90) s = 90; if (s < 40) s = 40; return s;
}

static id SV(NSDictionary *d, NSString *k, id def) {
    if (!d || ![d isKindOfClass:[NSDictionary class]]) return def;
    id v = [d objectForKey:k];
    if (!v || [v isKindOfClass:[NSNull class]]) return def;
    return v;
}
static NSString *ST(NSDictionary *d, NSString *k) {
    id v = SV(d, k, @"");
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    if ([v isKindOfClass:[NSString class]]) return v;
    return @"";
}
static NSArray *AR(NSDictionary *d, NSString *k) {
    id v = SV(d, k, nil);
    if (!v) return [NSArray array];
    if ([v isKindOfClass:[NSArray class]]) return v;
    return [NSArray arrayWithObject:v];
}
static BOOL IsImageURL(NSString *s) {
    if (!s.length) return NO;
    return [s hasPrefix:@"http://"] || [s hasPrefix:@"https://"];
}
static void LI(UIImageView *iv, NSString *u) {
    iv.image = nil;
    if (!IsImageURL(u)) return;
    [API img:u cb:^(UIImage *i) { if (i) iv.image = i; }];
}
static void Alert(NSString *t, NSString *m) {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:t message:m delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

#pragma mark - ListCell

@interface ListCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iv;
@property (nonatomic, strong) UILabel *ttl;
@property (nonatomic, strong) UILabel *sub;
@property (nonatomic, strong) UIView *line;
@end
@implementation ListCell
@synthesize iv = _iv, ttl = _ttl, sub = _sub, line = _line;
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (self) {
        self.backgroundColor = Card();
        self.selectionStyle = UITableViewCellSelectionStyleGray;
        _iv = [[UIImageView alloc] init];
        _iv.contentMode = UIViewContentModeScaleAspectFill;
        _iv.clipsToBounds = YES;
        _iv.layer.cornerRadius = 6;
        _iv.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1];
        [self.contentView addSubview:_iv];
        _ttl = [[UILabel alloc] init];
        _ttl.font = [UIFont boldSystemFontOfSize:(IsPad() ? 17 : 15)];
        _ttl.textColor = TitleC();
        _ttl.numberOfLines = 2;
        [self.contentView addSubview:_ttl];
        _sub = [[UILabel alloc] init];
        _sub.font = [UIFont systemFontOfSize:(IsPad() ? 13 : 12)];
        _sub.textColor = Subtitle();
        _sub.numberOfLines = 2;
        [self.contentView addSubview:_sub];
        _line = [[UIView alloc] init];
        _line.backgroundColor = Divider();
        [self.contentView addSubview:_line];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    CGFloat pad = IsPad() ? 14 : 10;
    CGFloat h = b.size.height;
    CGFloat imgS = ThumbSize(h);
    _iv.frame = CGRectMake(pad, (h - imgS) / 2, imgS, imgS);
    CGFloat textX = pad * 2 + imgS;
    CGFloat textW = b.size.width - textX - pad;
    if (textW < 100) textW = 100;
    CGFloat ttlH = (h - pad * 3) * 0.58;
    CGFloat subH = (h - pad * 3) * 0.42;
    _ttl.frame = CGRectMake(textX, pad, textW, ttlH);
    _sub.frame = CGRectMake(textX, pad + ttlH + 2, textW, subH);
    _line.frame = CGRectMake(textX, h - 0.5, b.size.width - textX, 0.5);
}
@end

#pragma mark - IntroCell

@interface IntroCell : UITableViewCell
@property (nonatomic, strong) UIImageView *cover;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UILabel *ovLbl;
@end
@implementation IntroCell
@synthesize cover = _cover, titleLbl = _titleLbl, ovLbl = _ovLbl;
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (self) {
        self.backgroundColor = Card();
        _cover = [[UIImageView alloc] init];
        _cover.contentMode = UIViewContentModeScaleAspectFill;
        _cover.clipsToBounds = YES;
        _cover.layer.cornerRadius = 6;
        _cover.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1];
        _cover.userInteractionEnabled = YES;
        [self.contentView addSubview:_cover];
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [UIFont boldSystemFontOfSize:(IsPad() ? 17 : 16)];
        _titleLbl.textColor = TitleC();
        _titleLbl.numberOfLines = 2;
        [self.contentView addSubview:_titleLbl];
        _ovLbl = [[UILabel alloc] init];
        _ovLbl.font = [UIFont systemFontOfSize:(IsPad() ? 14 : 12)];
        _ovLbl.textColor = Subtitle();
        _ovLbl.numberOfLines = 6;
        [self.contentView addSubview:_ovLbl];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    CGFloat pad = IsPad() ? 18 : 14;
    CGFloat h = b.size.height;
    CGFloat covH = h - pad * 2;
    CGFloat covW = covH * 0.72;
    CGFloat maxW = IsPad() ? 150 : 110;
    if (covW > maxW) { covW = maxW; covH = covW / 0.72; }
    _cover.frame = CGRectMake(pad, (h - covH) / 2, covW, covH);
    CGFloat textX = pad * 2 + covW;
    CGFloat textW = b.size.width - textX - pad;
    if (textW < 100) textW = 100;
    CGFloat ttlH = IsPad() ? 52 : 44;
    _titleLbl.frame = CGRectMake(textX, pad, textW, ttlH);
    _ovLbl.frame = CGRectMake(textX, pad + ttlH + 4, textW, h - pad * 2 - ttlH - 4);
}
@end

#pragma mark - 下载任务

@interface DownloadTask : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, copy) NSString *url, *title, *filePath;
@property (nonatomic, assign) int bid, ep, state;
@property (nonatomic, assign) long long totalBytes, downloadedBytes;
@property (nonatomic, strong) NSURLConnection *conn;
@property (nonatomic, strong) NSFileHandle *fh;
- (id)initWithUrl:(NSString *)url title:(NSString *)title bid:(int)bid ep:(int)ep;
- (void)start; - (void)pause; - (void)cancelTask;
@end

@implementation DownloadTask
@synthesize url = _url, title = _title, filePath = _filePath;
@synthesize bid = _bid, ep = _ep, state = _state;
@synthesize totalBytes = _totalBytes, downloadedBytes = _downloadedBytes;
@synthesize conn = _conn, fh = _fh;
- (id)initWithUrl:(NSString *)url title:(NSString *)title bid:(int)bid ep:(int)ep {
    self = [super init];
    if (self) {
        _url = [url copy]; _title = [title copy];
        _bid = bid; _ep = ep; _state = 0;
        NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/AniCh_videos"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        _filePath = [[dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%d_%d.mp4", bid, ep]] copy];
    }
    return self;
}
- (void)start {
    if (_state == 2 || _state == 1) return;
    _state = 1;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_url]];
    [req setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    if (_downloadedBytes > 0) [req setValue:[NSString stringWithFormat:@"bytes=%lld-", _downloadedBytes] forHTTPHeaderField:@"Range"];
    _conn = [NSURLConnection connectionWithRequest:req delegate:self];
}
- (void)pause {
    if (_state != 1) return;
    _state = 0;
    [_conn cancel]; _conn = nil;
    [_fh closeFile]; _fh = nil;
}
- (void)cancelTask {
    _state = 0;
    [_conn cancel]; _conn = nil;
    [_fh closeFile]; _fh = nil;
    [[NSFileManager defaultManager] removeItemAtPath:_filePath error:NULL];
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *hr = (NSHTTPURLResponse *)response;
        if (hr.statusCode == 206) {
            NSString *range = [[hr allHeaderFields] objectForKey:@"Content-Range"];
            NSRange slash = [range rangeOfString:@"/"];
            if (slash.location != NSNotFound) _totalBytes = [[range substringFromIndex:slash.location+1] longLongValue];
        } else _totalBytes = [response expectedContentLength];
    }
    if (!_fh) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:_filePath])
            [[NSFileManager defaultManager] createFileAtPath:_filePath contents:nil attributes:nil];
        _fh = [NSFileHandle fileHandleForWritingAtPath:_filePath];
        [_fh seekToEndOfFile];
    }
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_fh writeData:data];
    _downloadedBytes += data.length;
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    _state = 2;
    [_fh closeFile]; _fh = nil; _conn = nil;
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    _state = 3;
    [_fh closeFile]; _fh = nil; _conn = nil;
}
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space { return YES; }
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}
@end

#pragma mark - 下载管理

@interface DownloadManager : NSObject
+ (DownloadManager *)shared;
@property (nonatomic, strong) NSMutableArray *tasks;
- (DownloadTask *)addTaskWithUrl:(NSString *)url title:(NSString *)title bid:(int)bid ep:(int)ep;
- (void)removeTask:(DownloadTask *)task;
- (void)restoreFromDisk;
@end
@implementation DownloadManager
@synthesize tasks = _tasks;
+ (DownloadManager *)shared {
    static DownloadManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[DownloadManager alloc] init];
        [inst restoreFromDisk];
    });
    return inst;
}
- (id)init { self = [super init]; if (self) _tasks = [NSMutableArray array]; return self; }
- (void)restoreFromDisk {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/AniCh_videos"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) return;
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:NULL];
    for (NSString *f in files) {
        if (![f hasSuffix:@".mp4"]) continue;
        NSString *path = [dir stringByAppendingPathComponent:f];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:NULL];
        long long size = [[attrs objectForKey:NSFileSize] longLongValue];
        if (size < 1024) continue;
        NSString *base = [f stringByDeletingPathExtension];
        NSArray *parts = [base componentsSeparatedByString:@"_"];
        int bid = 0, ep = 0;
        if (parts.count >= 2) {
            bid = [[parts objectAtIndex:0] intValue];
            ep = [[parts objectAtIndex:1] intValue];
        }
        DownloadTask *t = [[DownloadTask alloc] initWithUrl:@"" title:[NSString stringWithFormat:@"[%d] 第%d集", bid, ep] bid:bid ep:ep];
        t.state = 2;
        t.totalBytes = size;
        t.downloadedBytes = size;
        [_tasks addObject:t];
    }
}
- (DownloadTask *)addTaskWithUrl:(NSString *)url title:(NSString *)title bid:(int)bid ep:(int)ep {
    for (DownloadTask *t in _tasks) if (t.bid == bid && t.ep == ep) return t;
    DownloadTask *t = [[DownloadTask alloc] initWithUrl:url title:title bid:bid ep:ep];
    [_tasks addObject:t];
    [t start];
    return t;
}
- (void)removeTask:(DownloadTask *)task { [task cancelTask]; [_tasks removeObject:task]; }
@end

#pragma mark - 接口声明

@class ListVC;
typedef void (^LoaderBlock)(ListVC *lv);

@interface SearchVC : UITableViewController <UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *sb;
@property (nonatomic, strong) NSMutableArray *rows;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end
@interface SettingsVC : UITableViewController <UIAlertViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *rows;
@end
@interface BangumiDetailVC : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>
@property (nonatomic, assign) int bid;
@property (nonatomic, strong) NSDictionary *detail;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray *rows;
- (id)initWithBid:(int)b;
@end
@interface ListVC : UITableViewController
@property (nonatomic, strong) NSMutableArray *rows;
@property (nonatomic, copy) LoaderBlock loader;
@property (nonatomic, assign) int mode;
- (void)feed:(NSArray *)a;
@end
@interface EpisodeVC : UITableViewController <UIActionSheetDelegate>
@property (nonatomic, assign) int bid;
@property (nonatomic, strong) NSMutableArray *eps;
- (id)initWithBid:(int)b;
@end
@interface DownloadListVC : UITableViewController <UIActionSheetDelegate>
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) DownloadTask *pendingTask;
@end
@interface VodVC : UIViewController
@property (nonatomic, assign) int bid, episode;
@property (nonatomic, copy) NSString *localPath, *localTitle;
@property (nonatomic, strong) AVPlayer *avp;
@property (nonatomic, strong) AVPlayerLayer *avl;
@property (nonatomic, strong) MPMoviePlayerController *mp;
@property (nonatomic, strong) UIView *playerView;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL stopped;
@property (nonatomic, assign) float playSpeed;
@property (nonatomic, strong) UIView *ctrlBar;
@property (nonatomic, strong) UISlider *progress;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, assign) BOOL controlsVisible;
- (id)initWithBid:(int)b episode:(int)e;
- (id)initWithLocalPath:(NSString *)path title:(NSString *)title;
@end

#pragma mark - 类扩展

@interface SearchVC () - (void)fill:(NSDictionary *)r; @end
@interface SettingsVC ()
- (void)editApi; - (void)doLoginDialog; - (void)doLogout; - (void)openDownloads; - (void)goBack;
@end
@interface BangumiDetailVC ()
- (void)load; - (void)onLongPressCover:(UILongPressGestureRecognizer *)g;
- (void)cacheEpisodeByPrompt; - (void)goBack;
- (void)imageSaved:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
@end
@interface ListVC () - (void)goBack; @end
@interface EpisodeVC ()
- (void)load; - (void)onLongPressEp:(UILongPressGestureRecognizer *)g; - (void)cacheEpisode:(int)ep; - (void)goBack;
@end
@interface DownloadListVC () - (void)refreshUI; - (void)toggleEdit; - (void)goBack; @end
@interface VodVC ()
- (void)loadVod; - (void)playUrl:(NSString *)real; - (void)tick;
- (NSTimeInterval)currentTime; - (NSTimeInterval)duration;
- (void)togglePlay; - (void)onSeekStart; - (void)onSeekEnd;
- (void)buildAVFControls; - (void)updateTimeLabel; - (void)closeSelf;
- (void)relayoutForOrientation;
- (void)tapOnVideo:(UITapGestureRecognizer *)g;
- (void)showControls; - (void)hideControls;
@end

#pragma mark - 搜索
@implementation SearchVC
@synthesize sb = _sb, rows = _rows, spinner = _spinner;
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = Bg();
    self.tableView.separatorColor = Divider();
    _rows = [NSMutableArray array];
    CGFloat w = self.view.bounds.size.width;
    _sb = [[UISearchBar alloc] initWithFrame:CGRectMake(0, kTopBarH, w, 44)];
    _sb.delegate = self;
    _sb.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _sb.placeholder = @"搜索番剧";
    _sb.tintColor = Accent();
    // 表头 = 顶栏占位 + 搜索框（搜索框在占位下面，不会被顶栏挡）
    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, kTopBarH + 44)];
    hdr.backgroundColor = [UIColor clearColor];
    hdr.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [hdr addSubview:_sb];
    self.tableView.tableHeaderView = hdr;
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.frame = CGRectMake((w - 20) / 2, 220, 20, 20);
    _spinner.hidesWhenStopped = YES;
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:_spinner];
    InstallTopBar(self, @"搜索", NULL);
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    LayoutTopBar(self);
    CGFloat w = self.view.bounds.size.width;
    UIView *hdr = self.tableView.tableHeaderView;
    if (hdr) {
        CGRect hf = hdr.frame;
        hf.size.width = w;
        hdr.frame = hf;
    }
    _sb.frame = CGRectMake(0, kTopBarH, w, 44);
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)s {
    [s resignFirstResponder];
    NSString *k = s.text;
    if (!k.length) return;
    [_rows removeAllObjects];
    [self.tableView reloadData];
    [_spinner startAnimating];
    [[API s] searchBg:k skip:0 cb:^(NSDictionary *r, NSError *e) {
        [_spinner stopAnimating];
        if (e) { Alert(@"网络错误", [e localizedDescription]); return; }
        if (!r || ![r count]) { Alert(@"搜索失败", @"服务器无响应，请重试"); return; }
        [self fill:r];
    }];
}
- (void)fill:(NSDictionary *)r {
    NSArray *d = AR(r, @"f1_pb");
    NSDictionary *b = SV(r, @"f3_pb", nil);
    if (!d.count) d = AR(b, @"f1_pb");
    for (NSDictionary *i in d) if ([i isKindOfClass:[NSDictionary class]]) [_rows addObject:i];
    [self.tableView reloadData];
    if (!_rows.count) Alert(@"无结果", @"没找到相关番剧");
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)_rows.count; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)i { return ListRowHeight(); }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *c = @"s";
    ListCell *cl = (ListCell *)[t dequeueReusableCellWithIdentifier:c];
    if (!cl) cl = [[ListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:c];
    NSDictionary *d = [_rows objectAtIndex:(NSUInteger)ip.row];
    NSString *title = ST(d, @"f2");
    if (!title.length) title = ST(d, @"f7");
    cl.ttl.text = title;
    cl.sub.text = [NSString stringWithFormat:@"ID %@  ·  %@/%@ 集", ST(d, @"f1"), ST(d, @"f3"), ST(d, @"f4")];
    NSString *im = ST(d, @"f7");
    if (!IsImageURL(im)) im = ST(d, @"f6");
    LI(cl.iv, im);
    return cl;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *d = [_rows objectAtIndex:(NSUInteger)ip.row];
    int bid = [ST(d, @"f1") intValue];
    if (!bid) bid = [ST(d, @"f2") intValue];
    if (!bid) { Alert(@"提示", @"此条目无番剧ID"); return; }
    BangumiDetailVC *v = [[BangumiDetailVC alloc] initWithBid:bid];
    [self.navigationController pushViewController:v animated:YES];
}
@end

#pragma mark - 设置
@implementation SettingsVC
@synthesize rows = _rows;
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = Bg();
    self.tableView.separatorColor = Divider();
    _rows = [NSArray arrayWithObjects:@"账号", @"缓存管理", @"修改 API 地址", @"播放器模式", @"播放倍速", @"关于", nil];
    self.tableView.tableHeaderView = TopSpacerView(self.view.bounds.size.width);
    InstallTopBar(self, @"设置", NULL);
}
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    [self.tableView reloadData];
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    LayoutTopBar(self);
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)_rows.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *c = @"st";
    UITableViewCell *cl = [t dequeueReusableCellWithIdentifier:c];
    if (!cl) cl = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:c];
    cl.backgroundColor = Card();
    cl.textLabel.text = [_rows objectAtIndex:(NSUInteger)ip.row];
    cl.textLabel.textColor = TitleC();
    cl.detailTextLabel.text = nil;
    cl.detailTextLabel.textColor = Subtitle();
    if (ip.row == 0) cl.detailTextLabel.text = [API s].token ? @"已登录" : @"未登录";
    if (ip.row == 1) cl.detailTextLabel.text = [NSString stringWithFormat:@"%d 个任务", (int)[[DownloadManager shared].tasks count]];
    if (ip.row == 2) cl.detailTextLabel.text = [API s].baseUrl;
    if (ip.row == 3) { NSString *m = [UD stringForKey:kPlayModeKey]; if (!m) m = @"MP"; cl.detailTextLabel.text = m; }
    if (ip.row == 4) { NSNumber *sp = [UD objectForKey:kPlaySpeedKey]; float v = sp ? [sp floatValue] : 1.0; cl.detailTextLabel.text = [NSString stringWithFormat:@"%.2gx", v]; }
    if (ip.row == 5) cl.detailTextLabel.text = @"v1.1";
    return cl;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.row == 0) {
        if ([API s].token) {
            UIActionSheet *s = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:@"退出登录" otherButtonTitles:nil];
            s.tag = 700;
            [s showInView:self.view];
        } else [self doLoginDialog];
        return;
    }
    if (ip.row == 1) { [self openDownloads]; return; }
    if (ip.row == 2) { [self editApi]; return; }
    if (ip.row == 3) {
        UIActionSheet *s = [[UIActionSheet alloc] initWithTitle:@"播放器" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"MPMoviePlayer（默认）", @"AVPlayer", nil];
        s.tag = 701; [s showInView:self.view]; return;
    }
    if (ip.row == 4) {
        UIActionSheet *s = [[UIActionSheet alloc] initWithTitle:@"倍速" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"0.5x", @"0.75x", @"1.0x", @"1.25x", @"1.5x", @"2.0x", nil];
        s.tag = 702; [s showInView:self.view]; return;
    }
    if (ip.row == 5) Alert(@"关于", @"AniCh iOS5 v1.1\nBy mougou666");
}
- (void)goBack { [self.navigationController popViewControllerAnimated:YES]; }
- (void)openDownloads { DownloadListVC *v = [[DownloadListVC alloc] init]; [self.navigationController pushViewController:v animated:YES]; }
- (void)editApi {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"修改 API" message:@"输入完整地址（含 https://）" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
    a.alertViewStyle = UIAlertViewStylePlainTextInput;
    [a textFieldAtIndex:0].text = [API s].baseUrl;
    a.tag = 800; [a show];
}
- (void)doLoginDialog {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"登录" message:@"用户名+密码" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
    a.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    a.tag = 801; [a show];
}
- (void)doLogout { [API s].token = nil; [UD removeObjectForKey:kTokenKey]; [self.tableView reloadData]; }
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)b {
    if (a.tag == 800 && b == 1) {
        NSString *url = [a textFieldAtIndex:0].text;
        if (!url.length) return;
        [API s].baseUrl = url;
        [UD setObject:url forKey:kBaseUrlKey];
        [self.tableView reloadData];
        Alert(@"成功", @"已更新 API 地址");
        return;
    }
    if (a.tag == 801 && b == 1) {
        NSString *u = [a textFieldAtIndex:0].text;
        NSString *p = [a textFieldAtIndex:1].text;
        if (!u.length || !p.length) return;
        [[API s] login:u pwd:p cb:^(NSDictionary *r, NSError *e) {
            if ([API s].token) {
                [UD setObject:[API s].token forKey:kTokenKey];
                [self.tableView reloadData];
                Alert(@"登录", @"成功");
            } else {
                NSString *m = e ? [e localizedDescription] : ST(r, @"f2");
                if (!m.length) m = @"登录失败";
                Alert(@"登录", m);
            }
        }];
    }
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)b {
    if (b < 0) return;
    if (s.tag == 700) { if (b == 0) [self doLogout]; }
    else if (s.tag == 701) { [UD setObject:(b == 1 ? @"AVF" : @"MP") forKey:kPlayModeKey]; [self.tableView reloadData]; }
    else if (s.tag == 702) {
        float sp[] = {0.5, 0.75, 1.0, 1.25, 1.5, 2.0};
        [UD setObject:[NSNumber numberWithFloat:sp[b]] forKey:kPlaySpeedKey];
        [self.tableView reloadData];
    }
}
@end

#pragma mark - 缓存管理
@implementation DownloadListVC
@synthesize refreshTimer = _refreshTimer, pendingTask = _pendingTask;
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = Bg();
    self.tableView.separatorColor = Divider();
    self.tableView.tableHeaderView = TopSpacerView(self.view.bounds.size.width);
    UIView *bar = InstallTopBar(self, @"缓存管理", @selector(goBack));
    UIButton *eb = [UIButton buttonWithType:UIButtonTypeCustom];
    eb.frame = CGRectMake(bar.bounds.size.width - 70, 0, 70, kTopBarH);
    eb.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [eb setTitle:@"编辑" forState:UIControlStateNormal];
    [eb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    eb.titleLabel.font = [UIFont systemFontOfSize:14];
    [eb addTarget:self action:@selector(toggleEdit) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:eb];
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refreshUI) userInfo:nil repeats:YES];
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    LayoutTopBar(self);
}
- (void)goBack { [self.navigationController popViewControllerAnimated:YES]; }
- (void)toggleEdit { [self.tableView setEditing:!self.tableView.editing animated:YES]; }
- (void)dealloc { [_refreshTimer invalidate]; }
- (void)refreshUI {
    if (self.tableView.editing) return;
    NSArray *visible = [self.tableView visibleCells];
    for (UITableViewCell *cell in visible) {
        NSIndexPath *ip = [self.tableView indexPathForCell:cell];
        if (!ip || ip.row >= (NSInteger)[[DownloadManager shared].tasks count]) continue;
        DownloadTask *task = [[DownloadManager shared].tasks objectAtIndex:(NSUInteger)ip.row];
        double pct = task.totalBytes > 0 ? (double)task.downloadedBytes / task.totalBytes * 100 : 0;
        NSString *stateStr = @"已暂停";
        if (task.state == 1) stateStr = @"下载中";
        else if (task.state == 2) stateStr = @"已完成";
        else if (task.state == 3) stateStr = @"失败";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  %.1f%%  (%.1f/%.1f MB)",
                                     stateStr, pct, task.downloadedBytes/1048576.0, task.totalBytes/1048576.0];
    }
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)[[DownloadManager shared].tasks count]; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)i { return DownloadRowHeight(); }
- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }
- (UITableViewCellEditingStyle)tableView:(UITableView *)t editingStyleForRowAtIndexPath:(NSIndexPath *)ip {
    return UITableViewCellEditingStyleDelete;
}
- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    if (ip.row >= (NSInteger)[[DownloadManager shared].tasks count]) return;
    DownloadTask *task = [[DownloadManager shared].tasks objectAtIndex:(NSUInteger)ip.row];
    [[DownloadManager shared] removeTask:task];
    [t deleteRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationFade];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *c = @"dl";
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:c];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:c];
    cell.backgroundColor = Card();
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.textColor = TitleC();
    cell.detailTextLabel.textColor = Subtitle();
    DownloadTask *task = [[DownloadManager shared].tasks objectAtIndex:(NSUInteger)ip.row];
    cell.textLabel.text = task.title;
    double pct = task.totalBytes > 0 ? (double)task.downloadedBytes / task.totalBytes * 100 : 0;
    NSString *stateStr = @"已暂停";
    if (task.state == 1) stateStr = @"下载中";
    else if (task.state == 2) stateStr = @"已完成";
    else if (task.state == 3) stateStr = @"失败";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  %.1f%%  (%.1f/%.1f MB)",
                                 stateStr, pct, task.downloadedBytes/1048576.0, task.totalBytes/1048576.0];
    return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (self.tableView.editing) return;
    if (ip.row >= (NSInteger)[[DownloadManager shared].tasks count]) return;
    DownloadTask *task = [[DownloadManager shared].tasks objectAtIndex:(NSUInteger)ip.row];
    if (task.state == 2) {
        VodVC *v = [[VodVC alloc] initWithLocalPath:task.filePath title:task.title];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:v];
        v.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:v action:@selector(closeSelf)];
        [self presentModalViewController:nav animated:YES];
        return;
    }
    _pendingTask = task;
    NSString *action2 = (task.state == 1) ? @"暂停" : @"继续";
    UIActionSheet *s = [[UIActionSheet alloc] initWithTitle:task.title delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:@"删除任务" otherButtonTitles:action2, nil];
    [s showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)b {
    if (b < 0) return;
    DownloadTask *task = _pendingTask;
    _pendingTask = nil;
    if (!task) return;
    if (b == s.destructiveButtonIndex) {
        NSUInteger idx = [[DownloadManager shared].tasks indexOfObject:task];
        [[DownloadManager shared] removeTask:task];
        if (idx != NSNotFound) {
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
        }
    } else if (b == s.firstOtherButtonIndex) {
        if (task.state == 1) [task pause];
        else [task start];
        [self.tableView reloadData];
    }
}
@end

#pragma mark - 番剧详情
@implementation BangumiDetailVC
@synthesize bid = _bid, detail = _detail, table = _table, rows = _rows;
- (id)initWithBid:(int)b { self = [super init]; if (self) _bid = b; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = Bg();
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _table = [[UITableView alloc] initWithFrame:CGRectMake(0, kTopBarH, w, h - kTopBarH) style:UITableViewStyleGrouped];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.backgroundColor = Bg();
    _table.separatorColor = Divider();
    _table.dataSource = self;
    _table.delegate = self;
    [self.view addSubview:_table];
    _rows = [NSArray arrayWithObjects:@"播放", @"缓存指定集", @"收藏", @"角色", @"制作", nil];
    InstallTopBar(self, @"番剧详情", @selector(goBack));
    [self load];
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    LayoutTopBar(self);
}
- (void)goBack { [self.navigationController popViewControllerAnimated:YES]; }
- (void)load {
    [[API s] bDetail:_bid cb:^(NSDictionary *r, NSError *e) {
        if (e) { Alert(@"错误", [e localizedDescription]); return; }
        if (r) { _detail = r; [_table reloadData]; }
    }];
}
- (void)onLongPressCover:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIImageView *iv = (UIImageView *)g.view;
    if (!iv.image) { Alert(@"提示", @"图片未加载完成"); return; }
    UIImageWriteToSavedPhotosAlbum(iv.image, self, @selector(imageSaved:didFinishSavingWithError:contextInfo:), NULL);
}
- (void)imageSaved:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    Alert(@"保存封面", error ? [error localizedDescription] : @"已保存到相册");
}
- (void)cacheEpisodeByPrompt {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"缓存指定集" message:@"输入集数（如 1、3、5）" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"缓存", nil];
    a.alertViewStyle = UIAlertViewStylePlainTextInput;
    a.tag = 400; [a show];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return s == 0 ? 1 : (NSInteger)_rows.count; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"简介（长按封面保存到相册）" : @"操作"; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)i { return i.section == 0 ? IntroRowHeight() : 52; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        static NSString *c = @"intro";
        IntroCell *cl = (IntroCell *)[t dequeueReusableCellWithIdentifier:c];
        if (!cl) {
            cl = [[IntroCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:c];
            cl.selectionStyle = UITableViewCellSelectionStyleNone;
            UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressCover:)];
            [cl.cover addGestureRecognizer:lp];
        }
        cl.titleLbl.text = ST(_detail, @"title");
        cl.ovLbl.text = ST(_detail, @"overview");
        NSString *cover = ST(_detail, @"image");
        if (!IsImageURL(cover)) cover = @"";
        LI(cl.cover, cover);
        return cl;
    }
    static NSString *c2 = @"act";
    UITableViewCell *cl = [t dequeueReusableCellWithIdentifier:c2];
    if (!cl) cl = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:c2];
    cl.backgroundColor = Card();
    cl.textLabel.text = [_rows objectAtIndex:(NSUInteger)ip.row];
    cl.textLabel.textColor = Accent();
    cl.textLabel.font = [UIFont boldSystemFontOfSize:15];
    cl.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cl;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) return;
    if (ip.row == 0) {
        EpisodeVC *v = [[EpisodeVC alloc] initWithBid:_bid];
        [self.navigationController pushViewController:v animated:YES];
    } else if (ip.row == 1) [self cacheEpisodeByPrompt];
    else if (ip.row == 2) {
        [[API s] colStatus:_bid cb:^(NSDictionary *r, NSError *e) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"收藏" message:@"选择操作" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"收藏", @"想追", @"看过", @"取消收藏", nil];
            a.tag = 300; [a show];
        }];
    } else if (ip.row == 3) {
        ListVC *v = [[ListVC alloc] init]; v.title = @"角色"; v.mode = 1;
        v.loader = ^(ListVC *lv) { [[API s] chars:_bid cb:^(NSDictionary *r, NSError *e) { [lv feed:AR(r, @"f1_pb")]; }]; };
        [self.navigationController pushViewController:v animated:YES];
    } else if (ip.row == 4) {
        ListVC *v = [[ListVC alloc] init]; v.title = @"制作"; v.mode = 2;
        v.loader = ^(ListVC *lv) { [[API s] persons:_bid cb:^(NSDictionary *r, NSError *e) { [lv feed:AR(r, @"f1_pb")]; }]; };
        [self.navigationController pushViewController:v animated:YES];
    }
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)b {
    if (a.tag == 400 && b == 1) {
        int ep = [[a textFieldAtIndex:0].text intValue];
        if (ep <= 0) { Alert(@"提示", @"无效集数"); return; }
        [[API s] vod:_bid ep:ep cb:^(NSDictionary *r, NSError *e) {
            if (e || !r) { Alert(@"失败", @"获取播放源失败"); return; }
            NSArray *v = AR(r, @"f1_pb");
            if (!v.count) v = AR(r, @"data");
            if (!v.count) { Alert(@"失败", @"无播放源"); return; }
            NSDictionary *f = [v objectAtIndex:0];
            NSString *raw = ST(f, @"f1");
            if (!raw.length) raw = ST(f, @"url");
            NSString *real = [[API s] decodeVod:raw];
            if (!real.length) real = raw;
            if (!real.length) { Alert(@"失败", @"URL 为空"); return; }
            NSString *title = [NSString stringWithFormat:@"[%d] 第%d集", _bid, ep];
            [[DownloadManager shared] addTaskWithUrl:real title:title bid:_bid ep:ep];
            Alert(@"已加入缓存", @"请到 设置 → 缓存管理 查看");
        }];
        return;
    }
    if (a.tag != 300) return;
    if (b == 1) [[API s] colBangumi:_bid type:@"collect" cb:^(NSDictionary *r, NSError *e) {}];
    else if (b == 2) [[API s] colBangumi:_bid type:@"wish" cb:^(NSDictionary *r, NSError *e) {}];
    else if (b == 3) [[API s] colBangumi:_bid type:@"watched" cb:^(NSDictionary *r, NSError *e) {}];
    else if (b == 4) [[API s] colCancel:_bid cb:^(NSDictionary *r, NSError *e) {}];
}
@end

#pragma mark - 通用列表
@implementation ListVC
@synthesize rows = _rows, loader = _loader, mode = _mode;
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = Bg();
    self.tableView.separatorColor = Divider();
    _rows = [NSMutableArray array];
    self.tableView.tableHeaderView = TopSpacerView(self.view.bounds.size.width);
    InstallTopBar(self, self.title ? self.title : @"列表", @selector(goBack));
    if (_loader) _loader(self);
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    LayoutTopBar(self);
}
- (void)goBack { [self.navigationController popViewControllerAnimated:YES]; }
- (void)feed:(NSArray *)a {
    [_rows removeAllObjects];
    for (NSDictionary *i in a) if ([i isKindOfClass:[NSDictionary class]]) [_rows addObject:i];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)_rows.count; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)i { return ListRowHeight(); }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *c = @"l";
    ListCell *cl = (ListCell *)[t dequeueReusableCellWithIdentifier:c];
    if (!cl) cl = [[ListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:c];
    NSDictionary *d = [_rows objectAtIndex:(NSUInteger)ip.row];
    NSString *title = @"";
    NSString *sub = @"";
    NSString *img = @"";
    if (_mode == 1) {
        title = ST(d, @"f3"); sub = ST(d, @"f2"); img = ST(d, @"f4");
    } else if (_mode == 2) {
        title = ST(d, @"f2"); sub = ST(d, @"f4"); img = ST(d, @"f3");
    } else if (_mode == 3) {
        title = ST(d, @"f2"); sub = ST(d, @"f9"); img = ST(d, @"f8");
    } else {
        title = ST(d, @"f2");
        if (!title.length) title = ST(d, @"f3");
        if (!title.length) title = ST(d, @"f1");
        sub = ST(d, @"f4");
        img = ST(d, @"f3");
        if (!IsImageURL(img)) img = ST(d, @"f7");
    }
    if (!IsImageURL(img)) img = @"";
    cl.ttl.text = title;
    cl.sub.text = sub;
    LI(cl.iv, img);
    return cl;
}
@end

#pragma mark - 剧集
@implementation EpisodeVC
@synthesize bid = _bid, eps = _eps;
- (id)initWithBid:(int)b { self = [super init]; if (self) _bid = b; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = Bg();
    self.tableView.separatorColor = Divider();
    _eps = [NSMutableArray array];
    self.tableView.tableHeaderView = TopSpacerView(self.view.bounds.size.width);
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressEp:)];
    [self.tableView addGestureRecognizer:lp];
    InstallTopBar(self, @"剧集", @selector(goBack));
    [self load];
}
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    LayoutTopBar(self);
}
- (void)goBack { [self.navigationController popViewControllerAnimated:YES]; }
- (void)load {
    [[API s] bEps:_bid cb:^(NSDictionary *r, NSError *e) {
        if (e) { Alert(@"错误", [e localizedDescription]); return; }
        NSArray *d = AR(r, @"f1_pb");
        for (NSDictionary *i in d) if ([i isKindOfClass:[NSDictionary class]]) [_eps addObject:i];
        [self.tableView reloadData];
        if (!_eps.count) Alert(@"无剧集", @"服务器返回空列表");
    }];
}
- (void)onLongPressEp:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [g locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:p];
    if (!ip) return;
    NSDictionary *d = [_eps objectAtIndex:(NSUInteger)ip.row];
    int ep = [ST(d, @"f2") intValue];
    UIActionSheet *s = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"第%d集", ep] delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"缓存该集", nil];
    s.tag = 900 + ep;
    [s showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)b {
    if (s.tag >= 900 && b == 0) { [self cacheEpisode:s.tag - 900]; }
}
- (void)cacheEpisode:(int)ep {
    [[API s] vod:_bid ep:ep cb:^(NSDictionary *r, NSError *e) {
        if (e || !r) { Alert(@"失败", @"获取播放源失败"); return; }
        NSArray *v = AR(r, @"f1_pb");
        if (!v.count) v = AR(r, @"data");
        if (!v.count) { Alert(@"失败", @"无播放源"); return; }
        NSDictionary *f = [v objectAtIndex:0];
        NSString *raw = ST(f, @"f1");
        if (!raw.length) raw = ST(f, @"url");
        NSString *real = [[API s] decodeVod:raw];
        if (!real.length) real = raw;
        if (!real.length) { Alert(@"失败", @"URL 为空"); return; }
        NSString *title = [NSString stringWithFormat:@"[%d] 第%d集", _bid, ep];
        [[DownloadManager shared] addTaskWithUrl:real title:title bid:_bid ep:ep];
        Alert(@"已加入缓存", @"请到 设置 → 缓存管理 查看");
    }];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)_eps.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *c = @"e";
    UITableViewCell *cl = [t dequeueReusableCellWithIdentifier:c];
    if (!cl) cl = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:c];
    cl.backgroundColor = Card();
    cl.textLabel.textColor = TitleC();
    cl.detailTextLabel.textColor = Subtitle();
    NSDictionary *d = [_eps objectAtIndex:(NSUInteger)ip.row];
    cl.textLabel.text = [NSString stringWithFormat:@"第 %@ 集  %@", ST(d, @"f2"), ST(d, @"f8")];
    cl.detailTextLabel.text = ST(d, @"f9");
    return cl;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *d = [_eps objectAtIndex:(NSUInteger)ip.row];
    int ep = [ST(d, @"f2") intValue];
    VodVC *v = [[VodVC alloc] initWithBid:_bid episode:ep];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:v];
    v.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:v action:@selector(closeSelf)];
    [self presentModalViewController:nav animated:YES];
}
@end

#pragma mark - 播放
@implementation VodVC
@synthesize bid = _bid, episode = _episode, localPath = _localPath, localTitle = _localTitle;
@synthesize avp = _avp, avl = _avl, mp = _mp, playerView = _playerView;
@synthesize timer = _timer, stopped = _stopped, playSpeed = _playSpeed;
@synthesize ctrlBar = _ctrlBar, progress = _progress, playBtn = _playBtn, timeLabel = _timeLabel, isSeeking = _isSeeking;
@synthesize controlsVisible = _controlsVisible;
- (id)initWithBid:(int)b episode:(int)e { self = [super init]; if (self) { _bid = b; _episode = e; } return self; }
- (id)initWithLocalPath:(NSString *)path title:(NSString *)title {
    self = [super init];
    if (self) { _localPath = [path copy]; _localTitle = [title copy]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    if (_localTitle) self.title = _localTitle;
    else self.title = [NSString stringWithFormat:@"第%d集", _episode];
    self.view.backgroundColor = [UIColor blackColor];
    NSNumber *sp = [UD objectForKey:kPlaySpeedKey];
    _playSpeed = sp ? [sp floatValue] : 1.0;
    _controlsVisible = YES;
    [self loadVod];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }
- (BOOL)shouldAutorotate { return YES; }
- (void)closeSelf {
    if (_avp) [_avp pause];
    if (_mp) [_mp stop];
    [_timer invalidate]; _timer = nil;
    [self dismissModalViewControllerAnimated:YES];
}
- (void)viewWillDisappear:(BOOL)a {
    [super viewWillDisappear:a];
    _stopped = YES;
    [_timer invalidate]; _timer = nil;
    if (_avp) { [_avp pause]; _avp = nil; }
    if (_mp) { [_mp stop]; _mp = nil; }
}
- (void)tapOnVideo:(UITapGestureRecognizer *)g {
    if (_controlsVisible) [self hideControls];
    else [self showControls];
}
- (void)showControls {
    _controlsVisible = YES;
    [UIView animateWithDuration:0.2 animations:^{ _ctrlBar.alpha = 1.0; }];
}
- (void)hideControls {
    _controlsVisible = NO;
    [UIView animateWithDuration:0.2 animations:^{ _ctrlBar.alpha = 0.0; }];
}
- (void)tick {
    if (_stopped || _isSeeking) return;
    NSTimeInterval cur = [self currentTime];
    NSTimeInterval dur = [self duration];
    if (dur > 0) {
        _progress.value = (float)(cur / dur);
        [self updateTimeLabel];
    }
    if (_avp) {
        if (_avp.rate > 0.0) _playBtn.selected = YES;
        else _playBtn.selected = NO;
    } else if (_mp) {
        if (_mp.playbackState == MPMoviePlaybackStatePlaying) _playBtn.selected = YES;
        else _playBtn.selected = NO;
    }
}
- (NSTimeInterval)currentTime {
    if (_mp) return _mp.currentPlaybackTime;
    if (_avp) { CMTime t = _avp.currentTime; if (CMTIME_IS_VALID(t)) return CMTimeGetSeconds(t); }
    return 0;
}
- (NSTimeInterval)duration {
    if (_mp) return _mp.duration;
    if (_avp && _avp.currentItem) {
        CMTime t = _avp.currentItem.duration;
        if (CMTIME_IS_VALID(t) && !CMTIME_IS_INDEFINITE(t)) return CMTimeGetSeconds(t);
    }
    return 0;
}
- (void)updateTimeLabel {
    int cur = (int)[self currentTime];
    int dur = (int)[self duration];
    _timeLabel.text = [NSString stringWithFormat:@"%d:%02d / %d:%02d", cur / 60, cur % 60, dur / 60, dur % 60];
}
- (void)togglePlay {
    if (_avp) {
        if (_avp.rate > 0.0) { [_avp pause]; _playBtn.selected = NO; }
        else { [_avp play]; [_avp setRate:_playSpeed]; _playBtn.selected = YES; }
    } else if (_mp) {
        if (_mp.playbackState == MPMoviePlaybackStatePlaying) { [_mp pause]; _playBtn.selected = NO; }
        else { [_mp play]; _playBtn.selected = YES; }
    }
}
- (void)onSeekStart { _isSeeking = YES; [self showControls]; }
- (void)onSeekEnd {
    NSTimeInterval dur = [self duration];
    if (dur <= 0) { _isSeeking = NO; return; }
    NSTimeInterval target = dur * _progress.value;
    if (_avp) [_avp seekToTime:CMTimeMakeWithSeconds(target, NSEC_PER_SEC)];
    else if (_mp) [_mp setCurrentPlaybackTime:target];
    _isSeeking = NO;
}
- (void)buildAVFControls {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat barH = 70;
    _ctrlBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - barH, w, barH)];
    _ctrlBar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.92];
    _ctrlBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _ctrlBar.alpha = 1.0;
    [self.view addSubview:_ctrlBar];
    _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _playBtn.frame = CGRectMake(12, (barH - 34) / 2, 34, 34);
    _playBtn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _playBtn.backgroundColor = Accent();
    _playBtn.layer.cornerRadius = 17;
    [_playBtn setTitle:@"▶" forState:UIControlStateNormal];
    [_playBtn setTitle:@"❚❚" forState:UIControlStateSelected];
    [_playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _playBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_playBtn addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
    _playBtn.selected = YES;
    [_ctrlBar addSubview:_playBtn];
    _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 130, (barH - 20) / 2, 120, 20)];
    _timeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _timeLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1];
    _timeLabel.font = [UIFont systemFontOfSize:12];
    _timeLabel.textAlignment = UITextAlignmentRight;
    _timeLabel.backgroundColor = [UIColor clearColor];
    _timeLabel.text = @"0:00 / 0:00";
    [_ctrlBar addSubview:_timeLabel];
    _progress = [[UISlider alloc] initWithFrame:CGRectMake(58, (barH - 34) / 2, w - 200, 34)];
    _progress.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _progress.minimumValue = 0;
    _progress.maximumValue = 1;
    _progress.value = 0;
    _progress.minimumTrackTintColor = Accent();
    _progress.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.25];
    [_progress addTarget:self action:@selector(onSeekStart) forControlEvents:UIControlEventTouchDown];
    [_progress addTarget:self action:@selector(onSeekEnd) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [_ctrlBar addSubview:_progress];
    [self performSelector:@selector(hideControls) withObject:nil afterDelay:5.0];
}
- (void)loadVod {
    if (_localPath) { [self playUrl:_localPath]; return; }
    [[API s] vod:_bid ep:_episode cb:^(NSDictionary *r, NSError *e) {
        if (e) { Alert(@"请求失败", [e localizedDescription]); return; }
        if (!r) { Alert(@"提示", @"服务器无响应"); return; }
        NSArray *v = AR(r, @"f1_pb");
        if (!v.count) v = AR(r, @"data");
        if (!v.count) { Alert(@"暂无播放源", @"服务器未返回播放地址"); return; }
        NSDictionary *f = [v objectAtIndex:0];
        NSString *raw = ST(f, @"f1");
        if (!raw.length) raw = ST(f, @"url");
        NSString *real = [[API s] decodeVod:raw];
        if (!real.length) real = raw;
        if (!real.length) { Alert(@"链接为空", raw); return; }
        [self playUrl:real];
    }];
}
- (void)playUrl:(NSString *)real {
    _playerView = [[UIView alloc] initWithFrame:self.view.bounds];
    _playerView.backgroundColor = [UIColor blackColor];
    _playerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_playerView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnVideo:)];
    [_playerView addGestureRecognizer:tap];
    NSURL *url = nil;
    if ([real hasPrefix:@"/"]) url = [NSURL fileURLWithPath:real];
    else url = [NSURL URLWithString:real];
    NSString *mode = [UD stringForKey:kPlayModeKey];
    if (!mode) mode = @"MP";
    if (_localPath) mode = @"AVF";
    if ([mode isEqualToString:@"AVF"]) {
        _avp = [AVPlayer playerWithURL:url];
        _avl = [AVPlayerLayer playerLayerWithPlayer:_avp];
        _avl.frame = _playerView.bounds;
        _avl.videoGravity = AVLayerVideoGravityResizeAspect;
        [_playerView.layer addSublayer:_avl];
        [self buildAVFControls];
        [_avp play];
        [_avp setRate:_playSpeed];
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    } else {
        _mp = [[MPMoviePlayerController alloc] initWithContentURL:url];
        _mp.view.frame = _playerView.bounds;
        _mp.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _mp.scalingMode = MPMovieScalingModeAspectFit;
        _mp.controlStyle = MPMovieControlStyleDefault;
        _mp.shouldAutoplay = YES;
        _mp.currentPlaybackRate = _playSpeed;
        [_playerView addSubview:_mp.view];
        [_mp prepareToPlay];
        [_mp play];
    }
}
- (void)relayoutForOrientation {
    CGRect b = self.view.bounds;
    _playerView.frame = b;
    _avl.frame = _playerView.bounds;
    _mp.view.frame = _playerView.bounds;
    CGFloat w = b.size.width;
    CGFloat h = b.size.height;
    if (_ctrlBar) {
        _ctrlBar.frame = CGRectMake(0, h - 70, w, 70);
        _progress.frame = CGRectMake(58, 18, w - 200, 34);
        _timeLabel.frame = CGRectMake(w - 130, 25, 120, 20);
    }
}
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)o duration:(NSTimeInterval)d {
    [self relayoutForOrientation];
}
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromO {
    [self relayoutForOrientation];
}
@end

#pragma mark - TabBarButton（按下时图标压暗，恢复点按反馈）

@interface TabBarButton : UIButton
@end

@implementation TabBarButton
- (void)applyIconAlpha {
    CGFloat a = self.selected ? 1.0 : 0.82;
    if (self.highlighted) a = 0.45;
    for (UIView *v in [self subviews]) {
        if ([v isKindOfClass:[UIImageView class]]) v.alpha = a;
    }
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self applyIconAlpha]; }
- (void)setSelected:(BOOL)s { [super setSelected:s]; [self applyIconAlpha]; }
@end

#pragma mark - MainVC（自定义顶栏 + 底部 TabBar）

@interface MainVC ()
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *customTabBar;
@property (nonatomic, strong) NSMutableArray *pages;
@property (nonatomic, strong) UINavigationController *searchNav;
@property (nonatomic, strong) UINavigationController *settingsNav;
@property (nonatomic, strong) NSArray *tabIconNames;
@property (nonatomic, assign) NSInteger currentIndex;
- (void)tabTapped:(UIButton *)s;
- (void)switchToIndex:(NSInteger)index;
- (void)updateTabBarStyle;
- (void)updateTabSelection;
- (void)layoutTabButtons;
- (void)layoutTabIcons;
@end

@implementation MainVC
@synthesize containerView = _containerView, customTabBar = _customTabBar, pages = _pages;
@synthesize searchNav = _searchNav, settingsNav = _settingsNav;
@synthesize tabIconNames = _tabIconNames, currentIndex = _currentIndex;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = Bg();
    
    NSString *savedToken = [UD stringForKey:kTokenKey];
    if (savedToken) [API s].token = savedToken;
    NSString *savedUrl = [UD stringForKey:kBaseUrlKey];
    if (savedUrl) [API s].baseUrl = savedUrl;
    
    SearchVC *s = [[SearchVC alloc] init];
    _searchNav = [[UINavigationController alloc] initWithRootViewController:s];
    SettingsVC *st = [[SettingsVC alloc] init];
    _settingsNav = [[UINavigationController alloc] initWithRootViewController:st];
    // 每个页面自己画 44pt 顶栏，系统导航栏不要
    _searchNav.navigationBarHidden = YES;
    _settingsNav.navigationBarHidden = YES;
    _pages = [[NSMutableArray alloc] initWithObjects:_searchNav, _settingsNav, nil];
    
    _tabIconNames = [[NSArray alloc] initWithObjects:@"tail_icon_main", @"tail_icon_myself", nil];
    
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat tabH = 50;
    
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h - tabH)];
    _containerView.backgroundColor = Bg();
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _containerView.clipsToBounds = YES;
    [self.view addSubview:_containerView];
    
    // 底部 TabBar
    _customTabBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - tabH, w, tabH)];
    _customTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_customTabBar];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 1)];
    line.backgroundColor = Divider();
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_customTabBar addSubview:line];
    
    NSArray *tt = [NSArray arrayWithObjects:@"搜索", @"设置", nil];
    CGFloat bw = w / 2.0f;
    for (NSInteger i = 0; i < 2; i++) {
        TabBarButton *b = (TabBarButton *)[TabBarButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(bw * i, 0, bw, tabH);
        b.tag = i;
        [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [b setTitle:[tt objectAtIndex:i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [b setTitleColor:Accent() forState:UIControlStateSelected];
        b.titleLabel.font = [UIFont systemFontOfSize:13];
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectZero];
        iv.tag = 1001;
        iv.userInteractionEnabled = NO;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        [b addSubview:iv];
        [_customTabBar addSubview:b];
    }
    [self updateTabBarStyle];
    [self layoutTabButtons];
    [self layoutTabIcons];
    
    _currentIndex = 0;
    [self addChildViewController:_searchNav];
    _searchNav.view.frame = _containerView.bounds;
    _searchNav.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_containerView addSubview:_searchNav.view];
    [_searchNav didMoveToParentViewController:self];
    [self updateTabSelection];
}

- (void)updateTabBarStyle {
    UIImage *bg = FindImage(@"tail_bg");
    for (UIView *v in [_customTabBar subviews]) if ([v isKindOfClass:[UIImageView class]]) [v removeFromSuperview];
    if (bg) {
        _customTabBar.backgroundColor = [UIColor blackColor];
        UIImageView *iv = [[UIImageView alloc] initWithFrame:_customTabBar.bounds];
        iv.image = bg;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_customTabBar insertSubview:iv atIndex:0];
    } else {
        _customTabBar.backgroundColor = Accent();
    }
    NSArray *tt = [NSArray arrayWithObjects:@"搜索", @"设置", nil];
    for (UIView *v in [_customTabBar subviews]) {
        if (![v isKindOfClass:[UIButton class]]) continue;
        UIButton *b = (UIButton *)v;
        UIImageView *iv = (UIImageView *)[b viewWithTag:1001];
        UIImage *icon = FindImage([_tabIconNames objectAtIndex:b.tag]);
        if (icon && iv) {
            iv.image = icon;
            iv.hidden = NO;
            [b setTitleColor:[UIColor clearColor] forState:UIControlStateNormal];
            [b setTitleColor:[UIColor clearColor] forState:UIControlStateSelected];
        } else {
            if (iv) { iv.image = nil; iv.hidden = YES; }
            [b setTitle:[tt objectAtIndex:b.tag] forState:UIControlStateNormal];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [b setTitleColor:Accent() forState:UIControlStateSelected];
            b.titleLabel.font = [UIFont systemFontOfSize:13];
        }
    }
    [self layoutTabIcons];
}

- (void)layoutTabButtons {
    CGFloat w = _customTabBar.bounds.size.width;
    CGFloat h = _customTabBar.bounds.size.height;
    CGFloat bw = w / 2.0f;
    NSInteger i = 0;
    for (UIView *v in [_customTabBar subviews]) {
        if (![v isKindOfClass:[UIButton class]]) continue;
        v.frame = CGRectMake(bw * i, 0, bw, h);
        i++;
    }
}

// 图标固定按 bar 高度算正方形 + AspectFit：够大、且绝不会被拉长
- (void)layoutTabIcons {
    CGFloat h = _customTabBar.bounds.size.height;
    for (UIView *v in [_customTabBar subviews]) {
        if (![v isKindOfClass:[UIButton class]]) continue;
        UIImageView *iv = (UIImageView *)[v viewWithTag:1001];
        if (!iv || iv.hidden) continue;
        CGFloat s = h - 6.0;
        if (s < 20.0) s = 20.0;
        iv.frame = CGRectMake((v.bounds.size.width - s) / 2.0, (h - s) / 2.0, s, s);
    }
}

- (void)updateTabSelection {
    for (UIView *v in [_customTabBar subviews]) {
        if (![v isKindOfClass:[TabBarButton class]]) continue;
        TabBarButton *b = (TabBarButton *)v;
        b.selected = (b.tag == _currentIndex);
    }
}

- (void)tabTapped:(UIButton *)s {
    if (s.tag == _currentIndex) return;
    [self switchToIndex:s.tag];
}

- (void)switchToIndex:(NSInteger)index {
    UIViewController *fromVC = (UIViewController *)[_pages objectAtIndex:(NSUInteger)_currentIndex];
    UIViewController *toVC = (UIViewController *)[_pages objectAtIndex:(NSUInteger)index];
    [fromVC willMoveToParentViewController:nil];
    [fromVC.view removeFromSuperview];
    [fromVC removeFromParentViewController];
    [self addChildViewController:toVC];
    toVC.view.frame = _containerView.bounds;
    toVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_containerView addSubview:toVC.view];
    [toVC didMoveToParentViewController:self];
    _currentIndex = index;
    [self updateTabSelection];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutTabButtons];
    [self layoutTabIcons];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return YES; }

@end
