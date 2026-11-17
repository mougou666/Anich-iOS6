#import "MainViewController.h"
#import "ApiClient.h"
#import <AVFoundation/AVFoundation.h>

#pragma mark - PlayerView

@interface PlayerView : UIView
@property (nonatomic, strong) AVPlayer *player;
@end

@implementation PlayerView

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayer *)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

@end

#pragma mark - BangumiCell

@interface BangumiCell : UITableViewCell
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *taglineLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation BangumiCell

@synthesize coverView = _coverView;
@synthesize titleLabel = _titleLabel;
@synthesize taglineLabel = _taglineLabel;
@synthesize statusLabel = _statusLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _coverView = [[UIImageView alloc] init];
        _coverView.contentMode = UIViewContentModeScaleAspectFill;
        _coverView.clipsToBounds = YES;
        _coverView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
        [self.contentView addSubview:_coverView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont boldSystemFontOfSize:15];
        _titleLabel.numberOfLines = 1;
        [self.contentView addSubview:_titleLabel];
        
        _taglineLabel = [[UILabel alloc] init];
        _taglineLabel.font = [UIFont systemFontOfSize:12];
        _taglineLabel.textColor = [UIColor grayColor];
        _taglineLabel.numberOfLines = 2;
        [self.contentView addSubview:_taglineLabel];
        
        _statusLabel = [[UILabel alloc] init];
        _statusLabel.font = [UIFont systemFontOfSize:11];
        _statusLabel.textColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1];
        [self.contentView addSubview:_statusLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    _coverView.frame = CGRectMake(10, 8, 70, h - 16);
    _titleLabel.frame = CGRectMake(90, 12, w - 100, 20);
    _taglineLabel.frame = CGRectMake(90, 34, w - 100, 36);
    _statusLabel.frame = CGRectMake(90, h - 24, w - 100, 16);
}

@end

#pragma mark - MainViewController

@interface MainViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, assign) NSInteger skip;
@property (nonatomic, assign) BOOL loading;
- (void)loadMore;
- (void)onLogin;
@end

@implementation MainViewController

@synthesize tableView = _tableView;
@synthesize items = _items;
@synthesize skip = _skip;
@synthesize loading = _loading;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"番剧";
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"登录"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(onLogin)];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 100;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    
    _items = [NSMutableArray array];
    _skip = 0;
    _loading = NO;
    
    [self loadMore];
}

- (void)loadMore {
    if (_loading) return;
    _loading = YES;
    [[ApiClient shared] fetchBangumiList:_skip callback:^(NSArray *items, NSError *error) {
        self.loading = NO;
        if (items.count) {
            [self.items addObjectsFromArray:items];
            self.skip = self.items.count;
            [self.tableView reloadData];
        }
    }];
}

- (void)onLogin {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"登录"
                                                    message:@"\n\n\n"
                                                   delegate:self
                                          cancelButtonTitle:@"取消"
                                          otherButtonTitles:@"确定", nil];
    UITextField *userField = [[UITextField alloc] initWithFrame:CGRectMake(12, 40, 260, 30)];
    userField.placeholder = @"用户名/邮箱";
    userField.borderStyle = UITextBorderStyleRoundedRect;
    userField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    userField.tag = 1001;
    
    UITextField *passField = [[UITextField alloc] initWithFrame:CGRectMake(12, 80, 260, 30)];
    passField.placeholder = @"密码";
    passField.borderStyle = UITextBorderStyleRoundedRect;
    passField.secureTextEntry = YES;
    passField.tag = 1002;
    
    [alert addSubview:userField];
    [alert addSubview:passField];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) return;
    UITextField *userField = (UITextField *)[alertView viewWithTag:1001];
    UITextField *passField = (UITextField *)[alertView viewWithTag:1002];
    NSString *user = userField.text ? userField.text : @"";
    NSString *pass = passField.text ? passField.text : @"";
    if (!user.length || !pass.length) return;
    
    [[ApiClient shared] login:user password:pass callback:^(BOOL success, NSString *message, NSString *token, NSError *error) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:success ? @"登录成功" : @"登录失败"
                                                    message:message ? message : @""
                                                   delegate:nil
                                          cancelButtonTitle:@"确定"
                                          otherButtonTitles:nil];
        [a show];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"BangumiCell";
    BangumiCell *cell = (BangumiCell *)[tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[BangumiCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    BangumiItem *item = [_items objectAtIndex:indexPath.row];
    cell.titleLabel.text = item.title;
    cell.taglineLabel.text = item.tagline;
    if (item.status.length) {
        if ([item.status isEqualToString:@"released"]) {
            cell.statusLabel.text = [NSString stringWithFormat:@"已完结 · %d话", (int)item.episodesTotal];
        } else if ([item.status isEqualToString:@"finale"]) {
            cell.statusLabel.text = [NSString stringWithFormat:@"完结 · %d话", (int)item.episodesTotal];
        } else {
            cell.statusLabel.text = [NSString stringWithFormat:@"更新至第%d话", (int)item.episode];
        }
    } else {
        cell.statusLabel.text = @"";
    }
    [ImageLoader load:item.image into:cell.coverView];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    BangumiItem *item = [_items objectAtIndex:indexPath.row];
    DetailViewController *d = [[DetailViewController alloc] init];
    d.bid = item.bid;
    d.bangumiTitle = item.title;
    [self.navigationController pushViewController:d animated:YES];
}

@end

#pragma mark - DetailViewController

@interface DetailViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) PlayerView *playerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *episodes;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, assign) NSInteger currentEpisode;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)playEpisode:(NSInteger)ep;
@end

@implementation DetailViewController

@synthesize playerView = _playerView;
@synthesize tableView = _tableView;
@synthesize episodes = _episodes;
@synthesize player = _player;
@synthesize currentEpisode = _currentEpisode;
@synthesize titleLabel = _titleLabel;
@synthesize bid = _bid;
@synthesize bangumiTitle = _bangumiTitle;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.bangumiTitle ? self.bangumiTitle : @"详情";
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGFloat w = self.view.bounds.size.width;
    _playerView = [[PlayerView alloc] initWithFrame:CGRectMake(0, 0, w, w * 9.0 / 16.0)];
    _playerView.backgroundColor = [UIColor blackColor];
    _playerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_playerView];
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, w * 9.0 / 16.0 + 6, w - 20, 20)];
    _titleLabel.font = [UIFont boldSystemFontOfSize:14];
    _titleLabel.text = @"选择剧集";
    _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_titleLabel];
    
    CGFloat tableTop = w * 9.0 / 16.0 + 30;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableTop, w, self.view.bounds.size.height - tableTop)
                                              style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 60;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    
    _episodes = [NSMutableArray array];
    _currentEpisode = -1;
    
    [[ApiClient shared] fetchEpisodes:self.bid callback:^(NSArray *episodes, NSError *error) {
        [self.episodes addObjectsFromArray:episodes];
        [self.tableView reloadData];
        if (episodes.count > 0) {
            EpisodeItem *first = [episodes objectAtIndex:0];
            [self playEpisode:first.sort];
        }
    }];
}

- (void)playEpisode:(NSInteger)ep {
    _currentEpisode = ep;
    [self.tableView reloadData];
    [[ApiClient shared] fetchVod:self.bid episode:ep callback:^(NSArray *urls, NSError *error) {
        if (!urls.count) return;
        VodItem *v = [urls objectAtIndex:0];
        NSString *realUrl = [ApiClient decodeVodUrl:v.url];
        NSURL *u = [NSURL URLWithString:realUrl];
        if (!u) return;
        if (self.player) {
            [self.player pause];
            self.player = nil;
        }
        self.player = [AVPlayer playerWithURL:u];
        self.playerView.player = self.player;
        [self.player play];
        NSUInteger i;
        for (i = 0; i < self.episodes.count; i++) {
            EpisodeItem *it = [self.episodes objectAtIndex:i];
            if (it.sort == ep) {
                self.titleLabel.text = [NSString stringWithFormat:@"第%d话 %@", (int)ep, it.title ? it.title : @""];
                break;
            }
        }
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _episodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EpisodeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    EpisodeItem *ep = [_episodes objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"第%d话 %@", (int)ep.sort, ep.title ? ep.title : @""];
    cell.detailTextLabel.text = ep.hasResource ? @"有资源" : @"暂无资源";
    if (ep.sort == _currentEpisode) {
        cell.textLabel.textColor = [UIColor colorWithRed:0.1 green:0.45 blue:0.8 alpha:1];
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    EpisodeItem *ep = [_episodes objectAtIndex:indexPath.row];
    [self playEpisode:ep.sort];
}

- (void)dealloc {
    if (_player) {
        [_player pause];
        _player = nil;
    }
    _playerView.player = nil;
}

@end