@import Foundation.NSDictionary;
@import Foundation.NSURLCache;
@import Foundation.NSURLConnection;
@import Foundation.NSURLRequest;
@class Promise;

#define PMKURLErrorFailingURLResponse @"PMKURLErrorFailingURLResponse"



@interface NSURLConnection (PromiseKit)
+ (Promise *)GET:(id)stringFormatOrNSURL, ...;
+ (Promise *)GET:(id)stringOrNSURL query:(NSDictionary *)parameters;
+ (Promise *)promise:(NSURLRequest *)rq;
@end

// ideally this would be from a pod, but I looked and all the pods imposed
// too much symbol overhead or used catgeories
NSString *NSDictionaryToURLQueryString(NSDictionary *parameters);



@interface NSURLCache (PromiseKit)
- (Promise *)promisedResponseForRequest:(NSURLRequest *)rq;
@end
