#import "PromiseKit/Promise.h"


@interface Promise (CommonCrypto)

/**
 Returns a promise that determines the md5 for the given input.
 The md5 is crunched in a background thread.
**/
+ (Promise *)md5:(NSString *)input;

@end
