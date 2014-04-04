#import "Chuzzle.h"
@import CoreFoundation.CFString;
@import CoreFoundation.CFURL;
@import Foundation.NSJSONSerialization;
@import Foundation.NSOperation;
@import Foundation.NSURL;
@import Foundation.NSURLError;
@import Foundation.NSURLResponse;
#import "PromiseKit/Deferred.h"
#import "PromiseKit+Foundation.h"

#define PMKURLErrorWithCode(x) [NSError errorWithDomain:NSURLErrorDomain code:x userInfo:NSDictionaryExtend(@{PMKURLErrorFailingURLResponse: rsp}, error.userInfo)]



static NSString *enc(NSString *in) {
    return (__bridge_transfer NSString *) CFURLCreateStringByAddingPercentEscapes(
            NULL,
            (__bridge CFStringRef)in,
            NULL,
            CFSTR("!*'();:@&=+$,/?%#[]"),
            kCFStringEncodingUTF8);
}

static BOOL NSHTTPURLResponseIsJSON(NSHTTPURLResponse *rsp) {
    NSString *type = rsp.allHeaderFields[@"Content-Type"];
    NSArray *bits = [type componentsSeparatedByString:@";"];
    return [bits.chuzzle containsObject:@"application/json"];
}

static BOOL NSHTTPURLResponseIsImage(NSHTTPURLResponse *rsp) {
    NSString *type = rsp.allHeaderFields[@"Content-Type"];
    NSArray *bits = [type componentsSeparatedByString:@";"];
    for (NSString *bit in bits) {
        if ([bit isEqualToString:@"image/jpeg"]) return YES;
        if ([bit isEqualToString:@"image/png"]) return YES;
    };
    return NO;
}

static NSDictionary *NSDictionaryExtend(NSDictionary *add, NSDictionary *base) {
    base = base.mutableCopy;
    [(id)base addEntriesFromDictionary:add];
    return base;
}

NSString *NSDictionaryToURLQueryString(NSDictionary *params) {
    if (!params.chuzzle)
        return nil;
    NSMutableString *query = [NSMutableString new];
    for (NSString *key in params) {
        NSString *value = [params objectForKey:key];
        [query appendFormat:@"%@=%@&", enc(key.description), enc(value.description)];
    }
    [query deleteCharactersInRange:NSMakeRange(query.length-1, 1)];
    return query;
}

static void ProcessURLResponse(NSHTTPURLResponse *rsp, NSData *data, Deferred *deferred) {
    if (NSHTTPURLResponseIsJSON(rsp)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            id error = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error)
                    [deferred reject:error];
                else
                    [deferred resolve:json];
            });
        });
#ifdef UIKIT_EXTERN
    } else if (NSHTTPURLResponseIsImage(rsp)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *image = [[UIImage alloc] initWithData:data];
            image = [[UIImage alloc] initWithCGImage:[image CGImage] scale:image.scale orientation:image.imageOrientation];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (image)
                    [deferred resolve:image];
                else
                    [deferred reject:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]];
            });
        });
#endif
    } else {
        [deferred resolve:data];
    }
}


@implementation NSURLConnection (PromiseKit)

+ (Promise *)GET:(id)urlFormat, ... {
    if ([urlFormat isKindOfClass:[NSURL class]])
        return [self GET:urlFormat query:nil];
    va_list arguments;
    va_start(arguments, urlFormat);
    urlFormat = [[NSString alloc] initWithFormat:urlFormat arguments:arguments];
    return [self GET:urlFormat query:nil];
}

+ (Promise *)GET:(id)url query:(NSDictionary *)params {
    if (params.chuzzle) {
        if ([url isKindOfClass:[NSURL class]])
            url = [url absoluteString];
        id query = NSDictionaryToURLQueryString(params);
        url = [NSString stringWithFormat:@"%@?%@", url, query];
    }
    if ([url isKindOfClass:[NSString class]])
        url = [NSURL URLWithString:url];

    return [self promise:[NSURLRequest requestWithURL:url]];
}

+ (Promise *)promise:(NSURLRequest *)rq {
    Deferred *deferred = [Deferred new];
    id q = [NSOperationQueue currentQueue] ?: [NSOperationQueue mainQueue];

    [NSURLConnection sendAsynchronousRequest:rq queue:q completionHandler:^(id rsp, id data, NSError *error) {
        if (error) {
            NSLog(@"PromiseKit: %@", error);
            [deferred reject:rsp ? PMKURLErrorWithCode(error.code) : error];
        } else if ([rsp statusCode] != 200) {
            NSLog(@"PromiseKit: non 200 response: %ld", [rsp statusCode]);
            [deferred reject:PMKURLErrorWithCode(NSURLErrorBadServerResponse)];
        } else
            ProcessURLResponse(rsp, data, deferred);
    }];
    return deferred.promise;
}

@end



@implementation NSURLCache (PromiseKit)

- (Promise *)promisedResponseForRequest:(NSURLRequest *)rq {
    Deferred *deferred = [Deferred new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSCachedURLResponse *rsp = [self cachedResponseForRequest:rq];  // can be significantly slow
        if (!rsp || [(id)rsp.response statusCode] != 200)
            [deferred reject:nil];
        else
            ProcessURLResponse((id)rsp.response, rsp.data, deferred);
    });
    return deferred.promise;
}

@end
