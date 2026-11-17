#import "API.h"
#import "PB.h"

static NSData *B64(NSString *str) {
    if (!str) return nil;
    static const char tbl[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    int8_t rev[128]; memset(rev, -1, sizeof(rev));
    for (int i = 0; i < 64; i++) rev[(uint8_t)tbl[i]] = (int8_t)i;
    NSUInteger len = [str length];
    NSMutableData *out = [NSMutableData dataWithCapacity:len * 3 / 4];
    int buf = 0, bits = 0;
    for (NSUInteger i = 0; i < len; i++) {
        unichar c = [str characterAtIndex:i];
        if (c == '=') break;
        if (c > 127) continue;
        int8_t v = rev[(uint8_t)c];
        if (v < 0) continue;
        buf = (buf << 6) | v; bits += 6;
        if (bits >= 8) { bits -= 8; uint8_t b = (uint8_t)((buf >> bits) & 0xFF); [out appendBytes:&b length:1]; }
    }
    return out;
}

static NSCache *gImgCache = nil;
static NSOperationQueue *gImgQueue = nil;

#pragma mark - 统一忽略证书的 HTTP 客户端

@interface HTTPClient : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableData *buf;
@property (nonatomic, copy) void(^cb)(NSData *, NSError *);
@end

static NSMutableArray *gLiveClients = nil;

@implementation HTTPClient

@synthesize buf = _buf;
@synthesize cb = _cb;

+ (void)fetch:(NSURLRequest *)req completion:(void(^)(NSData *, NSError *))cb {
    if (!gLiveClients) gLiveClients = [NSMutableArray array];
    HTTPClient *c = [[HTTPClient alloc] init];
    c.cb = cb;
    c.buf = [NSMutableData data];
    [gLiveClients addObject:c];
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:req delegate:c];
    [conn start];
}

- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)resp {
    [self.buf setLength:0];
}
- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data {
    [self.buf appendData:data];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)conn {
    if (self.cb) self.cb(self.buf, nil);
    [gLiveClients removeObject:self];
}
- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error {
    if (self.cb) self.cb(nil, error);
    [gLiveClients removeObject:self];
}
- (BOOL)connection:(NSURLConnection *)conn canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space {
    return YES;
}
- (void)connection:(NSURLConnection *)conn didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
             forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}
- (void)connection:(NSURLConnection *)conn willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
             forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}
@end

#pragma mark - API 前置声明

@interface API ()
+ (void)readMessage:(PBR *)r into:(NSMutableDictionary *)dict;
+ (void)addValue:(id)v forKey:(NSString *)k toDict:(NSMutableDictionary *)d;
- (NSString *)joinBytes:(NSData *)data;
- (NSDictionary *)jsonOrNil:(NSData *)data;
- (NSDictionary *)vodBytes:(NSData *)data;
- (NSDictionary *)smartParse:(NSData *)data;
- (void)req:(NSString *)path method:(NSString *)m params:(NSDictionary *)pr
       body:(NSData *)b contentType:(NSString *)ct auth:(BOOL)a
     isJSON:(BOOL)isJSON completion:(DCB)cb;
@end

#pragma mark - API 实现

@implementation API
@synthesize baseUrl = _baseUrl, biliUrl = _biliUrl, qqUrl = _qqUrl;
@synthesize token = _token, ua = _ua;

+ (API *)s {
    static API *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[API alloc] init];
        gImgCache = [[NSCache alloc] init];
        [gImgCache setCountLimit:300];
        gImgQueue = [[NSOperationQueue alloc] init];
        [gImgQueue setMaxConcurrentOperationCount:4];
    });
    return inst;
}

- (id)init {
    self = [super init];
    if (self) {
        self.baseUrl = @"https://anich.sends.eu.org";
        self.biliUrl = @"https://bili-dm.emmmm.eu.org";
        self.qqUrl = @"https://dm.video.qq.com";
        self.ua = @"AniCh iOS5/1.0";
    }
    return self;
}

#pragma mark - 底层请求（统一走 HTTPClient）

- (void)req:(NSString *)path method:(NSString *)m params:(NSDictionary *)pr
       body:(NSData *)b contentType:(NSString *)ct auth:(BOOL)a
     isJSON:(BOOL)isJSON completion:(DCB)cb {
    NSMutableString *us = [NSMutableString stringWithFormat:@"%@%@", self.baseUrl, path];
    if (pr && pr.count) {
        NSMutableArray *ps = [NSMutableArray array];
        for (NSString *k in pr) {
            NSString *e = [[[pr objectForKey:k] description] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if (e) [ps addObject:[NSString stringWithFormat:@"%@=%@", k, e]];
        }
        [us appendFormat:@"?%@", [ps componentsJoinedByString:@"&"]];
    }
    NSURL *u = [NSURL URLWithString:us];
    if (!u) { if (cb) cb(nil, [NSError errorWithDomain:@"API" code:-1 userInfo:nil]); return; }
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:u];
    [r setHTTPMethod:m ? m : @"GET"];
    [r setValue:self.ua forHTTPHeaderField:@"User-Agent"];
    if (ct) [r setValue:ct forHTTPHeaderField:@"Content-Type"];
    if (b) [r setHTTPBody:b];
    if (a && self.token) [r setValue:self.token forHTTPHeaderField:@"_"];
    NSLog(@"[API] -> %@ %@", m, us);
    [HTTPClient fetch:r completion:^(NSData *data, NSError *e) {
        NSDictionary *result = isJSON ? [self jsonOrNil:data] : [self smartParse:data];
        NSLog(@"[API] <- %@ %d bytes, keys=%@", path, (int)data.length, [result allKeys]);
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(result, e); });
    }];
}

- (void)reqJSON:(NSString *)path method:(NSString *)m params:(NSDictionary *)pr
           body:(NSData *)b contentType:(NSString *)ct auth:(BOOL)a completion:(DCB)cb {
    [self req:path method:m params:pr body:b contentType:ct auth:a isJSON:YES completion:cb];
}
- (void)reqPB:(NSString *)path method:(NSString *)m params:(NSDictionary *)pr
         body:(NSData *)b contentType:(NSString *)ct auth:(BOOL)a completion:(DCB)cb {
    [self req:path method:m params:pr body:b contentType:ct auth:a isJSON:NO completion:cb];
}

#pragma mark - 账号

- (void)login:(NSString *)u pwd:(NSString *)p cb:(DCB)cb {
    NSMutableData *d = [NSMutableData data];
    [d appendData:[PBW str:1 v:u ? u : @""]];
    [d appendData:[PBW str:2 v:p ? p : @""]];
    NSString *bs = [NSString stringWithFormat:@"data=%@", [self joinBytes:d]];
    [self reqPB:@"/login" method:@"POST" params:nil
           body:[bs dataUsingEncoding:NSUTF8StringEncoding]
    contentType:@"application/x-www-form-urlencoded" auth:NO completion:^(NSDictionary *r, NSError *e) {
        NSString *tk = [[r objectForKey:@"f3_pb"] objectForKey:@"f2"];
        if (tk && [tk isKindOfClass:[NSString class]]) self.token = tk;
        if (cb) cb(r, e);
    }];
}

- (void)getCode:(NSString *)e cb:(DCB)cb {
    NSString *bs = [NSString stringWithFormat:@"email=%@", e ? e : @""];
    [self reqJSON:@"/code" method:@"POST" params:nil
             body:[bs dataUsingEncoding:NSUTF8StringEncoding]
      contentType:@"application/x-www-form-urlencoded" auth:NO completion:cb];
}

- (void)register:(NSString *)e code:(NSString *)c name:(NSString *)n pwd:(NSString *)p cb:(DCB)cb {
    NSMutableData *d = [NSMutableData data];
    [d appendData:[PBW str:1 v:e ? e : @""]];
    [d appendData:[PBW str:2 v:c ? c : @""]];
    [d appendData:[PBW str:3 v:n ? n : @""]];
    [d appendData:[PBW str:4 v:p ? p : @""]];
    NSString *bs = [NSString stringWithFormat:@"data=%@", [self joinBytes:d]];
    [self reqPB:@"/register" method:@"POST" params:nil
           body:[bs dataUsingEncoding:NSUTF8StringEncoding]
    contentType:@"application/x-www-form-urlencoded" auth:NO completion:^(NSDictionary *r, NSError *e2) {
        NSString *tk = [[r objectForKey:@"f3_pb"] objectForKey:@"f2"];
        if (tk && [tk isKindOfClass:[NSString class]]) self.token = tk;
        if (cb) cb(r, e2);
    }];
}

- (void)chpwd:(NSString *)e code:(NSString *)c pwd:(NSString *)p cb:(DCB)cb {
    NSMutableData *d = [NSMutableData data];
    [d appendData:[PBW str:1 v:e ? e : @""]];
    [d appendData:[PBW str:2 v:c ? c : @""]];
    [d appendData:[PBW str:3 v:p ? p : @""]];
    NSString *bs = [NSString stringWithFormat:@"data=%@", [self joinBytes:d]];
    [self reqPB:@"/change_password" method:@"POST" params:nil
           body:[bs dataUsingEncoding:NSUTF8StringEncoding]
    contentType:@"application/x-www-form-urlencoded" auth:NO completion:cb];
}

- (void)chkEmail:(NSString *)e cb:(DCB)cb {
    NSString *bs = [NSString stringWithFormat:@"email=%@", e ? e : @""];
    [self reqJSON:@"/user/check" method:@"POST" params:nil
             body:[bs dataUsingEncoding:NSUTF8StringEncoding]
      contentType:@"application/x-www-form-urlencoded" auth:NO completion:cb];
}

- (void)chkName:(NSString *)n cb:(DCB)cb {
    NSString *bs = [NSString stringWithFormat:@"name=%@", n ? n : @""];
    [self reqJSON:@"/user/check" method:@"POST" params:nil
             body:[bs dataUsingEncoding:NSUTF8StringEncoding]
      contentType:@"application/x-www-form-urlencoded" auth:NO completion:cb];
}

- (void)getInit:(DCB)cb {
    [self reqPB:@"/init" method:@"GET" params:nil body:nil contentType:nil auth:YES completion:cb];
}

#pragma mark - 首页

- (void)latest:(int)s type:(NSString *)t skip:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSString stringWithFormat:@"%d", s], @"sort",
                       t ? t : @"all", @"type",
                       [NSString stringWithFormat:@"%d", k], @"skip", nil];
    [self reqPB:@"/latest" method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

- (void)tags:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", k] forKey:@"skip"];
    [self reqPB:@"/tags" method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

#pragma mark - 番剧

- (void)bList:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", k] forKey:@"skip"];
    [self reqPB:@"/bangumi/list" method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

- (void)bDetail:(int)i cb:(DCB)cb {
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/detail/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)bEps:(int)i cb:(DCB)cb {
    [self reqPB:[NSString stringWithFormat:@"/bangumi/episodes/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)bRel:(int)i cb:(DCB)cb {
    [self reqPB:[NSString stringWithFormat:@"/bangumi/related/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)bLatest:(DCB)cb {
    [self reqPB:@"/bangumi/latest" method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)bTag:(NSString *)t skip:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       t ? t : @"genre", @"type",
                       [NSString stringWithFormat:@"%d", k], @"skip", nil];
    [self reqJSON:@"/bangumi/tag" method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

- (void)vod:(int)i ep:(int)e cb:(DCB)cb {
    NSString *path = [NSString stringWithFormat:@"/vod/%d/%d", i, e];
    NSString *us = [NSString stringWithFormat:@"%@%@", self.baseUrl, path];
    NSLog(@"[API] -> GET %@", us);
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:us]];
    [r setValue:self.ua forHTTPHeaderField:@"User-Agent"];
    [HTTPClient fetch:r completion:^(NSData *data, NSError *err) {
        NSDictionary *result = [self vodBytes:data];
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(result, err); });
    }];
}

- (void)getDmk:(int)i ep:(int)e skip:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSString stringWithFormat:@"%d", i], @"bangumi",
                       [NSString stringWithFormat:@"%d", e], @"episode",
                       [NSString stringWithFormat:@"%d", k], @"skip", nil];
    [self reqPB:@"/danmaku" method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

- (void)postDmk:(int)i ep:(int)e text:(NSString *)t type:(int)ty time:(double)tm color:(NSString *)c cb:(DCB)cb {
    NSString *us = [NSString stringWithFormat:@"%@/danmaku?bangumi=%d&episode=%d", self.baseUrl, i, e];
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       t ? t : @"", @"text",
                       [NSNumber numberWithInt:ty], @"type",
                       [NSNumber numberWithDouble:tm], @"time",
                       c ? c : @"#ffffff", @"color", nil];
    NSData *body = [NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:us]];
    [r setHTTPMethod:@"POST"];
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [r setValue:self.ua forHTTPHeaderField:@"User-Agent"];
    if (self.token) [r setValue:self.token forHTTPHeaderField:@"_"];
    [r setHTTPBody:body];
    [HTTPClient fetch:r completion:^(NSData *data, NSError *e2) {
        NSDictionary *result = [self jsonOrNil:data];
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(result, e2); });
    }];
}

- (void)biliDmk:(int)oid seg:(int)s cb:(DCB)cb {
    NSString *us = [NSString stringWithFormat:@"%@/?type=1&oid=%d&segment_index=%d", self.biliUrl, oid, s];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:us]];
    [r setValue:self.ua forHTTPHeaderField:@"User-Agent"];
    [HTTPClient fetch:r completion:^(NSData *d, NSError *e) {
        NSDictionary *result = [self smartParse:d];
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(result, e); });
    }];
}

- (void)qqDmk:(NSString *)v page:(int)p cb:(DCB)cb {
    NSString *vid = [v lastPathComponent];
    int n = 30000;
    NSString *path = [NSString stringWithFormat:@"/barrage/segment/%@/t/v1/%d/%d", vid, n * (p - 1), n * p];
    NSString *us = [NSString stringWithFormat:@"%@%@", self.qqUrl, path];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:us]];
    [r setValue:self.ua forHTTPHeaderField:@"User-Agent"];
    [HTTPClient fetch:r completion:^(NSData *d, NSError *e) {
        NSDictionary *result = [self jsonOrNil:d];
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(result, e); });
    }];
}

#pragma mark - 角色人物

- (void)chars:(int)i cb:(DCB)cb {
    [self reqPB:[NSString stringWithFormat:@"/bangumi/characters/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)char:(int)i cb:(DCB)cb {
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/character/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)charBg:(int)i skip:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", k] forKey:@"skip"];
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/character/%d/bangumi", i] method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

- (void)persons:(int)i cb:(DCB)cb {
    [self reqPB:[NSString stringWithFormat:@"/bangumi/persons/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)person:(int)i cb:(DCB)cb {
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/person/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)personBg:(int)i skip:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", k] forKey:@"skip"];
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/person/%d/bangumi", i] method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

#pragma mark - 搜索

- (void)searchPic:(NSString *)k skip:(int)s cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       k ? k : @"", @"keyword",
                       [NSString stringWithFormat:@"%d", s], @"skip", nil];
    [self reqPB:@"/search" method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

- (void)searchBg:(NSString *)k skip:(int)s cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       k ? k : @"", @"keyword",
                       [NSString stringWithFormat:@"%d", s], @"skip", nil];
    [self reqPB:@"/bangumi/search" method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

#pragma mark - 标签

- (void)tagInfo:(NSString *)t cb:(DCB)cb {
    NSString *e = [t stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self reqPB:[NSString stringWithFormat:@"/t/%@/info", e] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

- (void)tagList:(NSString *)t skip:(int)k cb:(DCB)cb {
    NSString *e = [t stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", k] forKey:@"skip"];
    [self reqPB:[NSString stringWithFormat:@"/t/%@", e] method:@"GET" params:p body:nil contentType:nil auth:NO completion:cb];
}

#pragma mark - 帖子

- (void)thread:(int)i cb:(DCB)cb {
    [self reqPB:[NSString stringWithFormat:@"/r/%d", i] method:@"GET" params:nil body:nil contentType:nil auth:NO completion:cb];
}

#pragma mark - 收藏

- (void)colStatus:(int)i cb:(DCB)cb {
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/%d/collect/status", i] method:@"GET" params:nil body:nil contentType:nil auth:YES completion:cb];
}

- (void)colBangumi:(int)i type:(NSString *)t cb:(DCB)cb {
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/%d/collect/%@", i, t] method:@"GET" params:nil body:nil contentType:nil auth:YES completion:cb];
}

- (void)colCancel:(int)i cb:(DCB)cb {
    [self reqJSON:[NSString stringWithFormat:@"/bangumi/%d/collect/cancel", i] method:@"DELETE" params:nil body:nil contentType:nil auth:YES completion:cb];
}

- (void)colList:(NSString *)t page:(int)p cb:(DCB)cb {
    NSDictionary *pr = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", p] forKey:@"page"];
    [self reqJSON:[NSString stringWithFormat:@"/action/collect/%@", t] method:@"GET" params:pr body:nil contentType:nil auth:YES completion:cb];
}

#pragma mark - 评论

- (void)comments:(NSString *)t id:(NSString *)i skip:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObjectsAndKeys:
                       t ? t : @"", @"type",
                       i ? i : @"", @"id",
                       [NSString stringWithFormat:@"%d", k], @"skip", nil];
    [self reqJSON:@"/comment" method:@"GET" params:p body:nil contentType:nil auth:YES completion:cb];
}

- (void)postComment:(NSString *)t id:(NSString *)i parent:(NSString *)pr reply:(NSString *)r contents:(NSString *)c cb:(DCB)cb {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (t) [d setObject:t forKey:@"type"];
    if (i) [d setObject:i forKey:@"id"];
    if (pr) [d setObject:pr forKey:@"parent"];
    if (r) [d setObject:r forKey:@"reply"];
    if (c) [d setObject:c forKey:@"contents"];
    NSData *body = [NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];
    [self reqJSON:@"/comment" method:@"POST" params:nil body:body contentType:@"application/json" auth:YES completion:cb];
}

- (void)cmtReplies:(NSString *)i skip:(int)k cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%d", k] forKey:@"skip"];
    [self reqJSON:[NSString stringWithFormat:@"/comment/%@/replies", i] method:@"GET" params:p body:nil contentType:nil auth:YES completion:cb];
}

- (void)cmtLike:(NSString *)i cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObject:(i ? i : @"") forKey:@"id"];
    [self reqJSON:@"/comment/like" method:@"GET" params:p body:nil contentType:nil auth:YES completion:cb];
}

- (void)cmtUnLike:(NSString *)i cb:(DCB)cb {
    NSDictionary *p = [NSDictionary dictionaryWithObject:(i ? i : @"") forKey:@"id"];
    [self reqJSON:@"/comment/like" method:@"DELETE" params:p body:nil contentType:nil auth:YES completion:cb];
}

#pragma mark - 工具

- (NSString *)joinBytes:(NSData *)data {
    const uint8_t *b = (const uint8_t *)[data bytes];
    NSUInteger L = [data length];
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:L];
    for (NSUInteger i = 0; i < L; i++) [a addObject:[NSString stringWithFormat:@"%d", b[i]]];
    return [a componentsJoinedByString:@","];
}

- (NSDictionary *)jsonOrNil:(NSData *)data {
    if (!data) return nil;
    NSError *e = nil;
    id o = [NSJSONSerialization JSONObjectWithData:data options:0 error:&e];
    if (e || ![o isKindOfClass:[NSDictionary class]]) return nil;
    return o;
}

- (NSDictionary *)smartParse:(NSData *)data {
    if (!data || !data.length) return nil;
    const uint8_t *b = [data bytes];
    if (b[0] == '{' || b[0] == '[') {
        NSError *e = nil;
        id o = [NSJSONSerialization JSONObjectWithData:data options:0 error:&e];
        if (!e && [o isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[PB] JSON 响应: %@", o);
            return o;
        }
    }
    return [API parsePB:data];
}

- (NSDictionary *)vodBytes:(NSData *)data {
    if (!data || !data.length) return nil;
    const uint8_t *b = [data bytes];
    if (b[0] == '{') {
        NSError *e = nil;
        id o = [NSJSONSerialization JSONObjectWithData:data options:0 error:&e];
        if (!e && [o isKindOfClass:[NSDictionary class]]) return o;
    }
    NSError *e = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&e];
    if (!e && [obj isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)obj;
        if (!arr.count) return nil;
        NSMutableData *bytes = [NSMutableData dataWithCapacity:arr.count];
        for (id n in arr) {
            if ([n isKindOfClass:[NSNumber class]]) {
                uint8_t x = (uint8_t)[n intValue];
                [bytes appendBytes:&x length:1];
            }
        }
        return [API parsePB:bytes];
    }
    return [API parsePB:data];
}

- (NSString *)decodeVod:(NSString *)u {
    if (!u || u.length < 5) return @"";
    NSString *s = [NSString stringWithFormat:@"%@%@", [u substringToIndex:3], [u substringFromIndex:4]];
    NSData *d = B64(s);
    if (!d) return @"";
    NSString *r = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    return r ? r : @"";
}

+ (NSDictionary *)parsePB:(NSData *)data {
    if (!data || !data.length) return nil;
    PBR *r = [[PBR alloc] initWithData:data];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [API readMessage:r into:dict];
    return dict;
}

+ (void)addValue:(id)v forKey:(NSString *)k toDict:(NSMutableDictionary *)d {
    id ex = [d objectForKey:k];
    if (!ex) [d setObject:v forKey:k];
    else if ([ex isKindOfClass:[NSMutableArray class]]) [(NSMutableArray *)ex addObject:v];
    else { NSMutableArray *a = [NSMutableArray array]; [a addObject:ex]; [a addObject:v]; [d setObject:a forKey:k]; }
}

+ (void)readMessage:(PBR *)r into:(NSMutableDictionary *)d {
    while ([r hasMore]) {
        int f = 0, wt = 0;
        if ([r tag:&f wt:&wt] < 0) break;
        NSString *k = [NSString stringWithFormat:@"f%d", f];
        switch (wt) {
            case 0: [API addValue:[NSNumber numberWithUnsignedLongLong:[r varint]] forKey:k toDict:d]; break;
            case 1: [API addValue:[NSNumber numberWithDouble:[r dbl]] forKey:k toDict:d]; break;
            case 2: {
                NSData *b = [r bytes];
                NSString *s = [[NSString alloc] initWithData:b encoding:NSUTF8StringEncoding];
                if (s && [s length] > 0) [API addValue:s forKey:k toDict:d];
                NSMutableDictionary *sub = [NSMutableDictionary dictionary];
                [API readMessage:[[PBR alloc] initWithData:b] into:sub];
                if ([sub count] > 0) [API addValue:sub forKey:[k stringByAppendingString:@"_pb"] toDict:d];
                break;
            }
            case 5: [API addValue:[NSNumber numberWithUnsignedInt:[r u32]] forKey:k toDict:d]; break;
            default: [r skip:wt]; break;
        }
    }
}

+ (void)img:(NSString *)u cb:(ICB)cb {
    if (!u.length) { if (cb) cb(nil); return; }
    UIImage *c = [gImgCache objectForKey:u];
    if (c) { if (cb) cb(c); return; }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:u]];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46" forHTTPHeaderField:@"User-Agent"];
    [HTTPClient fetch:req completion:^(NSData *d, NSError *e) {
        UIImage *i = d ? [UIImage imageWithData:d] : nil;
        NSLog(@"[IMG] %@ %d bytes", [u lastPathComponent], (int)d.length);
        if (i) [gImgCache setObject:i forKey:u];
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(i); });
    }];
}

@end