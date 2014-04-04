@import Foundation;
#import <CommonCrypto/CommonDigest.h>
#import "PromiseKit/Deferred.h"
#import "PromiseKit+CommonCrypto.h"


@implementation Promise (CommonCrypto)

+ (Promise *)md5:(NSString *)input {
    Deferred *d = [Deferred new];
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        const char *cstr = [input UTF8String];
        NSUInteger const clen = [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        unsigned char result[16];
        CC_MD5(cstr, (CC_LONG)clen, result);
        NSString *out = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
             result[0],  result[1],  result[2],  result[3],
             result[4],  result[5],  result[6],  result[7],
             result[8],  result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];

        [d resolve:out];
    });
    return d.promise;
}

@end
