#import "ApiClient.h"
#include <stdint.h>
#include <string.h>

#pragma mark - Protobuf Reader

@interface PBReader : NSObject {
    NSData *_data;
    NSUInteger _pos;
}
- (id)initWithData:(NSData *)data;
- (BOOL)hasMore;
- (uint64_t)readVarint;
- (double)readDouble;
- (NSString *)readString;
- (NSData *)readBytes;
- (void)skipField:(int)wire;
@end

@implementation PBReader

- (id)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        _data = data;
        _pos = 0;
    }
    return self;
}

- (BOOL)hasMore {
    return _pos < _data.length;
}

- (uint64_t)readVarint {
    uint64_t result = 0;
    int shift = 0;
    const uint8_t *bytes = (const uint8_t *)_data.bytes;
    while (_pos < _data.length && shift < 64) {
        uint8_t b = bytes[_pos++];
        result |= ((uint64_t)(b & 0x7F)) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
    }
    return result;
}

- (double)readDouble {
    if (_pos + 8 > _data.length) { _pos = _data.length; return 0; }
    uint64_t bits = 0;
    memcpy(&bits, ((const uint8_t *)_data.bytes) + _pos, 8);
    _pos += 8;
    double d = 0;
    memcpy(&d, &bits, 8);
    return d;
}

- (NSData *)readBytes {
    uint64_t len = [self readVarint];
    if (_pos + len > _data.length) { _pos = _data.length; return nil; }
    NSData *sub = [_data subdataWithRange:NSMakeRange(_pos, (NSUInteger)len)];
    _pos += (NSUInteger)len;
    return sub;
}

- (NSString *)readString {
    NSData *sub = [self readBytes];
    if (!sub) return nil;
    NSString *s = [[NSString alloc] initWithData:sub encoding:NSUTF8StringEncoding];
    return s;
}

- (void)skipField:(int)wire {
    switch (wire) {
        case 0: [self readVarint]; break;
        case 1: _pos += 8; break;
        case 2: { uint64_t len = [self readVarint]; _pos += (NSUInteger)len; break; }
        case 5: _pos += 4; break;
        default: _pos = _data.length; break;
    }
    if (_pos > _data.length) _pos = _data.length;
}

@end

#pragma mark - Models

@implementation BangumiItem
@synthesize bid, title, image, tagline, status, episode, episodesTotal, date;

+ (id)decode:(NSData *)data {
    BangumiItem *item = [[BangumiItem alloc] init];
    PBReader *r = [[PBReader alloc] initWithData:data];
    while ([r hasMore]) {
        uint64_t tag = [r readVarint];
        int field = (int)(tag >> 3);
        int wire = (int)(tag & 0x7);
        switch (field) {
            case 1: item.bid = (NSInteger)[r readVarint]; break;
            case 2: item.title = [r readString]; break;
            case 3: item.episode = (NSInteger)[r readVarint]; break;
            case 4: item.episodesTotal = (NSInteger)[r readVarint]; break;
            case 5: item.status = [r readString]; break;
            case 6: item.date = [r readDouble]; break;
            case 7: item.image = [r readString]; break;
            case 8: item.tagline = [r readString]; break;
            default: [r skipField:wire]; break;
        }
    }
    return item;
}
@end

@implementation VodItem
@synthesize url, sort, caption;

+ (id)decode:(NSData *)data {
    VodItem *item = [[VodItem alloc] init];
    PBReader *r = [[PBReader alloc] initWithData:data];
    while ([r hasMore]) {
        uint64_t tag = [r readVarint];
        int field = (int)(tag >> 3);
        int wire = (int)(tag & 0x7);
        switch (field) {
            case 1: item.url = [r readString]; break;
            case 2: item.sort = (NSInteger)[r readVarint]; break;
            case 3: [r skipField:wire]; break;
            case 4: item.caption = [r readString]; break;
            default: [r skipField:wire]; break;
        }
    }
    return item;
}
@end

@implementation EpisodeItem
@synthesize sort, title, image, overview, hasResource, duration, airdate, biliCid, biliHmtCid, qqId;

+ (id)decode:(NSData *)data {
    EpisodeItem *item = [[EpisodeItem alloc] init];
    PBReader *r = [[PBReader alloc] initWithData:data];
    while ([r hasMore]) {
        uint64_t tag = [r readVarint];
        int field = (int)(tag >> 3);
        int wire = (int)(tag & 0x7);
        switch (field) {
            case 1: item.hasResource = [r readVarint] != 0; break;
            case 2: item.sort = (NSInteger)[r readVarint]; break;
            case 3: item.airdate = [r readDouble]; break;
            case 4: item.duration = (NSInteger)[r readVarint]; break;
            case 5: {
                NSData *sub = [r readBytes];
                PBReader *sr = [[PBReader alloc] initWithData:sub];
                NSString *site = nil;
                NSString *sid = nil;
                while ([sr hasMore]) {
                    uint64_t t2 = [sr readVarint];
                    int f2 = (int)(t2 >> 3);
                    int w2 = (int)(t2 & 0x7);
                    if (f2 == 1) site = [sr readString];
                    else if (f2 == 2) sid = [sr readString];
                    else [sr skipField:w2];
                }
                if ([site isEqualToString:@"bili_cid"]) item.biliCid = sid;
                else if ([site isEqualToString:@"bili_hmt_cid"]) item.biliHmtCid = sid;
                else if ([site isEqualToString:@"qq"]) item.qqId = sid;
                break;
            }
            case 6: [r skipField:wire]; break;
            case 7: item.image = [r readString]; break;
            case 8: item.title = [r readString]; break;
            case 9: item.overview = [r readString]; break;
            default: [r skipField:wire]; break;
        }
    }
    return item;
}
@end

#pragma mark - Base64URL

static NSData *DecodeBase64URL(NSString *s) {
    if (s.length == 0) return nil;
    NSString *str = [[s stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
                     stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSMutableString *clean = [NSMutableString string];
    NSUInteger i;
    for (i = 0; i < str.length; i++) {
        unichar c = [str characterAtIndex:i];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '+' || c == '/' || c == '=') {
            [clean appendFormat:@"%C", c];
        }
    }
    while (clean.length % 4 != 0) [clean appendString:@"="];
    
    static const char *alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    int8_t table[256];
    memset(table, -1, sizeof(table));
    for (i = 0; i < 64; i++) table[(unsigned char)alphabet[i]] = (int8_t)i;
    
    NSMutableData *result = [NSMutableData data];
    const char *chars = [clean UTF8String];
    if (!chars) return nil;
    NSUInteger len = strlen(chars);
    for (i = 0; i + 3 < len; i += 4) {
        int v0 = table[(unsigned char)chars[i]];
        int v1 = table[(unsigned char)chars[i+1]];
        int v2 = table[(unsigned char)chars[i+2]];
        int v3 = table[(unsigned char)chars[i+3]];
        if (v0 < 0 || v1 < 0) break;
        uint32_t triple = ((uint32_t)v0 << 18) | ((uint32_t)v1 << 12) |
        ((v2 < 0 ? 0 : v2) << 6) | (v3 < 0 ? 0 : v3);
        uint8_t b0 = (triple >> 16) & 0xFF;
        uint8_t b1 = (triple >> 8) & 0xFF;
        uint8_t b2 = triple & 0xFF;
        [result appendBytes:&b0 length:1];
        if (chars[i+2] != '=') [result appendBytes:&b1 length:1];
        if (chars[i+3] != '=') [result appendBytes:&b2 length:1];
    }
    return result;
}

#pragma mark - ApiClient

@interface ApiClient () {
    NSOperationQueue *_queue;
}
@end

@implementation ApiClient

@synthesize baseUrl, token, userAgent;

+ (id)shared {
    static ApiClient *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[ApiClient alloc] init];
    });
    return s;
}

- (id)init {
    self = [super init];
    if (self) {
        self.baseUrl = @"https://anich.sends.eu.org";
        self.userAgent = @"xs iOS 1.0.0";
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 4;
    }
    return self;
}

- (NSMutableURLRequest *)requestWithPath:(NSString *)path {
    NSString *full = [self.baseUrl stringByAppendingString:path];
    NSString *encoded = [full stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:encoded];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    [req setTimeoutInterval:20];
    return req;
}

+ (NSString *)encodeTokenHeader:(NSString *)tokenStr {
    if (!tokenStr.length) return @"";
    NSMutableData *data = [NSMutableData data];
    NSData *t = [tokenStr dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t tag1 = (1 << 3) | 2;
    [data appendBytes:&tag1 length:1];
    uint8_t len1 = (uint8_t)t.length;
    [data appendBytes:&len1 length:1];
    [data appendData:t];
    
    unsigned long long ms = (unsigned long long)([[NSDate date] timeIntervalSince1970] * 1000.0) + 60000;
    NSString *timeHex = [NSString stringWithFormat:@"%llx", ms];
    NSData *ti = [timeHex dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t tag2 = (2 << 3) | 2;
    [data appendBytes:&tag2 length:1];
    uint8_t len2 = (uint8_t)ti.length;
    [data appendBytes:&len2 length:1];
    [data appendData:ti];
    
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSMutableString *s = [NSMutableString string];
    NSUInteger i;
    for (i = 0; i < data.length; i++) {
        if (i > 0) [s appendString:@","];
        [s appendFormat:@"%d", bytes[i]];
    }
    return s;
}

+ (NSString *)encodeLoginBody:(NSString *)user password:(NSString *)password {
    NSMutableData *data = [NSMutableData data];
    NSData *u = [user dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t t1 = (1 << 3) | 2;
    [data appendBytes:&t1 length:1];
    uint8_t len1 = (uint8_t)u.length;
    [data appendBytes:&len1 length:1];
    [data appendData:u];
    
    NSData *p = [password dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t t2 = (2 << 3) | 2;
    [data appendBytes:&t2 length:1];
    uint8_t len2 = (uint8_t)p.length;
    [data appendBytes:&len2 length:1];
    [data appendData:p];
    
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSMutableString *s = [NSMutableString stringWithString:@"data="];
    NSUInteger i;
    for (i = 0; i < data.length; i++) {
        if (i > 0) [s appendString:@","];
        [s appendFormat:@"%d", bytes[i]];
    }
    return s;
}

- (void)fetchBangumiList:(NSInteger)skip callback:(ApiListCallback)cb {
    NSString *path = [NSString stringWithFormat:@"/bangumi/list?skip=%d&type=&lang=&year=&genre=&mark=", (int)skip];
    NSMutableURLRequest *req = [self requestWithPath:path];
    [NSURLConnection sendAsynchronousRequest:req queue:_queue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(nil, err); });
            return;
        }
        NSMutableArray *list = [NSMutableArray array];
        PBReader *r = [[PBReader alloc] initWithData:data];
        while ([r hasMore]) {
            uint64_t tag = [r readVarint];
            int field = (int)(tag >> 3);
            int wire = (int)(tag & 0x7);
            if (field == 1 && wire == 2) {
                NSData *sub = [r readBytes];
                BangumiItem *it = [BangumiItem decode:sub];
                if (it) [list addObject:it];
            } else {
                [r skipField:wire];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(list, nil); });
    }];
}

- (void)fetchEpisodes:(NSInteger)bid callback:(ApiEpisodesCallback)cb {
    NSString *path = [NSString stringWithFormat:@"/bangumi/episodes/%d", (int)bid];
    NSMutableURLRequest *req = [self requestWithPath:path];
    [NSURLConnection sendAsynchronousRequest:req queue:_queue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(nil, err); });
            return;
        }
        NSMutableArray *list = [NSMutableArray array];
        PBReader *r = [[PBReader alloc] initWithData:data];
        while ([r hasMore]) {
            uint64_t tag = [r readVarint];
            int field = (int)(tag >> 3);
            int wire = (int)(tag & 0x7);
            if (field == 1 && wire == 2) {
                NSData *sub = [r readBytes];
                EpisodeItem *ep = [EpisodeItem decode:sub];
                if (ep) [list addObject:ep];
            } else {
                [r skipField:wire];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(list, nil); });
    }];
}

- (void)fetchVod:(NSInteger)bid episode:(NSInteger)ep callback:(ApiVodCallback)cb {
    NSString *path = [NSString stringWithFormat:@"/vod/%d/%d", (int)bid, (int)ep];
    NSMutableURLRequest *req = [self requestWithPath:path];
    [NSURLConnection sendAsynchronousRequest:req queue:_queue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(nil, err); });
            return;
        }
        NSMutableArray *list = [NSMutableArray array];
        PBReader *r = [[PBReader alloc] initWithData:data];
        while ([r hasMore]) {
            uint64_t tag = [r readVarint];
            int field = (int)(tag >> 3);
            int wire = (int)(tag & 0x7);
            if (field == 1 && wire == 2) {
                NSData *sub = [r readBytes];
                VodItem *v = [VodItem decode:sub];
                if (v) [list addObject:v];
            } else {
                [r skipField:wire];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(list, nil); });
    }];
}

- (void)login:(NSString *)user password:(NSString *)password callback:(ApiLoginCallback)cb {
    NSMutableURLRequest *req = [self requestWithPath:@"/login"];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString *body = [ApiClient encodeLoginBody:user password:password];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    [NSURLConnection sendAsynchronousRequest:req queue:_queue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(NO, @"网络错误", nil, err); });
            return;
        }
        BOOL success = NO;
        NSString *message = nil;
        NSString *tokenStr = nil;
        PBReader *r = [[PBReader alloc] initWithData:data];
        while ([r hasMore]) {
            uint64_t tag = [r readVarint];
            int field = (int)(tag >> 3);
            int wire = (int)(tag & 0x7);
            if (field == 1 && wire == 0) {
                success = ![r readVarint];
            } else if (field == 2 && wire == 2) {
                message = [r readString];
            } else if (field == 3 && wire == 2) {
                NSData *sub = [r readBytes];
                PBReader *br = [[PBReader alloc] initWithData:sub];
                while ([br hasMore]) {
                    uint64_t t2 = [br readVarint];
                    int f2 = (int)(t2 >> 3);
                    int w2 = (int)(t2 & 0x7);
                    if (f2 == 2 && w2 == 2) {
                        tokenStr = [br readString];
                    } else {
                        [br skipField:w2];
                    }
                }
            } else {
                [r skipField:wire];
            }
        }
        if (success && tokenStr.length) {
            self.token = [ApiClient encodeTokenHeader:tokenStr];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(success, message, tokenStr, nil); });
    }];
}

+ (NSString *)decodeVodUrl:(NSString *)url {
    if (url.length < 5) return url;
    NSMutableString *m = [url mutableCopy];
    [m deleteCharactersInRange:NSMakeRange(3, 1)];
    NSData *d = DecodeBase64URL(m);
    if (!d) return url;
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    return s ? s : url;
}

@end

#pragma mark - ImageCache

@implementation ImageCache {
    NSCache *_cache;
}

+ (id)shared {
    static ImageCache *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[ImageCache alloc] init]; });
    return s;
}

- (id)init {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 200;
        _cache.totalCostLimit = 50 * 1024 * 1024;
    }
    return self;
}

- (UIImage *)imageForKey:(NSString *)key {
    return [_cache objectForKey:key];
}

- (void)setImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) return;
    NSUInteger cost = (NSUInteger)(image.size.width * image.size.height * 4);
    [_cache setObject:image forKey:key cost:cost];
}

@end

@implementation ImageLoader

+ (void)load:(NSString *)url into:(UIImageView *)iv {
    if (!url.length || !iv) return;
    UIImage *cached = [[ImageCache shared] imageForKey:url];
    if (cached) { iv.image = cached; return; }
    iv.image = nil;
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return;
    NSURLRequest *req = [NSURLRequest requestWithURL:u];
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (!data) return;
        UIImage *img = [UIImage imageWithData:data];
        if (!img) return;
        [[ImageCache shared] setImage:img forKey:url];
        iv.image = img;
    }];
}

@end