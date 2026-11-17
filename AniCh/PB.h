#import <Foundation/Foundation.h>
@interface PBW : NSObject
+ (NSData *)str:(int)f v:(NSString *)s;
@end
@interface PBR : NSObject
- (id)initWithData:(NSData *)d;
- (BOOL)hasMore;
- (int)tag:(int *)f wt:(int *)w;
- (uint64_t)varint;
- (uint32_t)u32;
- (double)dbl;
- (NSData *)bytes;
- (void)skip:(int)w;
@end