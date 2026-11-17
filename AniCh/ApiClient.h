#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^ApiListCallback)(NSArray *items, NSError *error);
typedef void(^ApiEpisodesCallback)(NSArray *episodes, NSError *error);
typedef void(^ApiVodCallback)(NSArray *urls, NSError *error);
typedef void(^ApiLoginCallback)(BOOL success, NSString *message, NSString *token, NSError *error);

@interface BangumiItem : NSObject
@property (nonatomic, assign) NSInteger bid;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *image;
@property (nonatomic, copy) NSString *tagline;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) NSInteger episode;
@property (nonatomic, assign) NSInteger episodesTotal;
@property (nonatomic, assign) double date;
@end

@interface VodItem : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, assign) NSInteger sort;
@property (nonatomic, copy) NSString *caption;
@end

@interface EpisodeItem : NSObject
@property (nonatomic, assign) NSInteger sort;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *image;
@property (nonatomic, copy) NSString *overview;
@property (nonatomic, assign) BOOL hasResource;
@property (nonatomic, assign) NSInteger duration;
@property (nonatomic, assign) double airdate;
@property (nonatomic, copy) NSString *biliCid;
@property (nonatomic, copy) NSString *biliHmtCid;
@property (nonatomic, copy) NSString *qqId;
@end

@interface ApiClient : NSObject
+ (id)shared;
@property (nonatomic, copy) NSString *baseUrl;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *userAgent;
- (void)fetchBangumiList:(NSInteger)skip callback:(ApiListCallback)cb;
- (void)fetchEpisodes:(NSInteger)bid callback:(ApiEpisodesCallback)cb;
- (void)fetchVod:(NSInteger)bid episode:(NSInteger)ep callback:(ApiVodCallback)cb;
- (void)login:(NSString *)user password:(NSString *)password callback:(ApiLoginCallback)cb;
+ (NSString *)decodeVodUrl:(NSString *)url;
@end

@interface ImageCache : NSObject
+ (id)shared;
- (UIImage *)imageForKey:(NSString *)key;
- (void)setImage:(UIImage *)image forKey:(NSString *)key;
@end

@interface ImageLoader : NSObject
+ (void)load:(NSString *)url into:(UIImageView *)iv;
@end