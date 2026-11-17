#import "PB.h"
@implementation PBW
+ (NSData *)vi:(uint64_t)v{NSMutableData*d=[NSMutableData data];while(v>0x7F){uint8_t b=(v&0x7F)|0x80;[d appendBytes:&b length:1];v>>=7;}uint8_t b=v&0x7F;[d appendBytes:&b length:1];return d;}
+ (NSData *)str:(int)f v:(NSString *)s{NSMutableData*o=[NSMutableData data];[o appendData:[self vi:((uint64_t)f<<3)|2]];NSData*b=[s dataUsingEncoding:NSUTF8StringEncoding];[o appendData:[self vi:b.length]];[o appendData:b];return o;}
@end
@implementation PBR{NSUInteger _p,_l;const uint8_t*_b;}
- (id)initWithData:(NSData *)d{self=[super init];if(self){_b=(const uint8_t*)[d bytes];_l=[d length];_p=0;}return self;}
- (BOOL)hasMore{return _p<_l;}
- (int)tag:(int*)f wt:(int*)w{if(_p>=_l)return -1;uint64_t k=[self varint];if(f)*f=(int)(k>>3);if(w)*w=(int)(k&7);return 0;}
- (uint64_t)varint{uint64_t r=0;int s=0;while(_p<_l){uint8_t b=_b[_p++];r|=((uint64_t)(b&0x7F))<<s;if(!(b&0x80))break;s+=7;if(s>=64)break;}return r;}
- (uint32_t)u32{return (uint32_t)[self varint];}
- (double)dbl{if(_p+8>_l)return 0;uint64_t b=0;memcpy(&b,_b+_p,8);_p+=8;double d=0;memcpy(&d,&b,8);return d;}
- (NSData *)bytes{uint64_t n=[self varint];if(_p+n>_l)return[NSData data];NSData*d=[NSData dataWithBytes:_b+_p length:(NSUInteger)n];_p+=n;return d;}
- (void)skip:(int)w{switch(w){case 0:[self varint];break;case 1:_p+=8;break;case 2:{uint64_t n=[self varint];_p+=n;break;}case 5:_p+=4;break;default:_p=_l;}}
@end