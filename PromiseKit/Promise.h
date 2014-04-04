@import Foundation.NSObject;


/**
 Documented online: http://promisekit.org
**/

@interface Promise : NSObject
- (Promise *(^)(id))then;
- (Promise *(^)(id))catch;
+ (Promise *)when:(id)promiseOrArrayOfPromisesOrValue;
+ (Promise *)until:(id(^)(void))blockReturningPromiseOrArrayOfPromises catch:(id)catchHandler;
+ (Promise *)promiseWithValue:(id)value;
@end


#define PMKErrorDomain @"PMKErrorDomain"
#define PMKThrown @"PMKThrown"
#define PMKErrorCodeThrown 1
#define PMKErrorCodeUnknown 2
