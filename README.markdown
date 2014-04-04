Modern development is highly asyncronous; isn’t it about time iOS developers had tools that made programming asyncronously powerful, easy and delightful?

PromiseKit is not just a Promises implementation, it is also a collection of helper functions that make the typical asyncronous patterns we use in iOS development delightful *too*.


#Using PromiseKit

In your [Podfile](http://guides.cocoapods.org/syntax/podfile.html):

```ruby
pod 'PromiseKit'
```


#What is a Promise?

Synchronous code is clean code:

```objc
- (void)setGravatarForEmail:(NSString *)email {
    NSString *md5 = md5(email);
    NSString *url = [@"http://gravatar.com/avatar/%@" stringByAppendingString:md5];
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    self.imageView.image = [UIImage imageWithData:data];
}
```

Clean but blocking: the UI lags: the user rates you one star.

The asyncronous analog suffers from *“rightward-drift”*:


```objc
- (void)setGravatarForEmail:(NSString *)email {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *md5 = md5(email);
        NSString *url = [@"http://gravatar.com/avatar/%@" stringByAppendingString:md5];
        NSURLRequest *rq = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        [NSURLConnection sendAsyncronousRequest:rq queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            UIImage *gravatarImage = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageView.image = gravatarImage;
            });
        }];
    });
}
```

The code that does the actual work is now buried inside asyncronicity boilerplate. It is harder to read. The code is less clean.

A promise is an intent to accomplish an asyncronous task:

```objc
#import "PromiseKit.h"

- (void)setGravatarForEmail:(NSString *)email {
    [Promise md5:email].then(^(NSString *md5){
        return [NSURLConnection GET:@"http://gravatar.com/avatar/%@", md5];
    }).then(^(UIImage *gravatarImage){
        self.imageView.image = gravatarImage;
    });
}
```


#Error Handling

Synchronous code allows us to use exceptions:

```objc
- (void)setGravatarForEmail:(NSString *)email {
    @try {
        NSString *md5 = md5(email);
        NSString *url = [@"http://gravatar.com/avatar/%@" stringByAppendingString:md5];
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
        self.imageView.image = [UIImage imageWithData:data];
    } @catch (NSError *error) {
        //TODO
    }
}
```

Error handling with asyncronous code is notoriously tricky:

```objc
- (void)setGravatarForEmail:(NSString *)email {
    void (^errorHandler)(NSError *) = ^(NSError *error){
        //TODO
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSString *md5 = md5(email);
            NSString *url = [@"http://gravatar.com/avatar/%@" stringByAppendingString:md5];
            NSURLRequest *rq = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
            [NSURLConnection sendAsyncronousRequest:rq queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {

                // the code is now misleading since exceptions thrown in this
                // block will not bubble up to our @catch

                if (connectionError) {
                    errorHandler(connectionError);
                } else {
                    UIImage *img = [UIImage imageWithData:data];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.imageView.image = img;
                    });
                }
            }];
        } @catch (NSError *err) {
            errorHandler(err);
        }
    });
}
```

Yuck! Hideous! And *even more* rightward-drift.

Promises have elegant error handling:

```objc
#import "PromiseKit.h"

- (void)setGravatarForEmail:(NSString *)email {
    [Promise md5:email].then(^(NSString *md5){
        return [NSURLConnection GET:@"http://gravatar.com/avatar/%@", md5];
    }).then(^(UIImage *gravatarImage){
        self.imageView.image = gravatarImage;
    }).catch(^(NSError *error){
        //TODO
    });
}
```

Errors bubble up to the first `catch` handler in the chain.


#Asyncronous State Machines

Promises represent the future value of a task. Our app should show a spinner until the gravatar has loaded, but only the first time. Firstly we should refactor our gravatar method to return a promise:

```objc
- (Promise *)gravatarForEmail:(NSString *)email {
    return [Promise md5:email].then(^(NSString *md5){
        return [NSURLConnection GET:@"http://gravatar.com/avatar/%@", md5];
    }).catch(^(NSError *error){
        //TODO
    });
}

- (void)viewDidLoad {
    // This is a property of type: `Promise *`
    self.gravatarPromise = [self gravatarForEmail:self.email];
    
    self.gravatarPromise.then(^(UIImage *image){
        // Isn’t it nice? Promises are a consistent interface for asyncronicity!
        self.imageView.image = image;
    });
}
```

We have to set another `UIImageView` to that gravatar image. Normally you would either load the gravatar again (which is inefficient) or store state about the fact the gravatar is loading and that you should wait, you would then need to react to that state in the final step of your asyncronous-block-tree-of-doom. Promises make it easy:

```objc
- (void)setThatOtherImageView {
    self.gravatarPromise.then(^(UIImage *img){
        self.otherImageView.image = img;
    });
}
```

If a Promise already has a value then the then block is executed immediately. If it is still ***pending*** then the then block is executed once the Promise is ***fulfilled***.

A key understanding about Promises is that they can exist in two states, *pending* and *fulfilled*. The fulfilled state is either a value or an `NSError` object (Promise values are never `nil`). A Promise can move from pending to fulfilled **exactly once**.


#Waiting on Multiple Asyncronous Operations

One powerful reason to use asyncronous variants is so we can do two or more asyncronous operations simultaneously. However writing code that acts when the simultaneous operations have all completed is hard. Not so with PromiseKit:

```objc
id a = [NSURLConnection GET:url1];
id b = [NSURLConnection GET:url2];
[Promise when:@[a, b]].then(^(NSArray *results){
    // do something with both 
}).catch(^(NSError *error){
    // with `when`, if any of the Promises fail, the `catch` handler is executed
    NSArray *suberrors = error.userInfo[PMKThrown];

    // `suberrors` may not just be `NSError` objects, any promises that succeeded
    // have their success values passed to this handler also. Thus you could
    // return a value from this `catch` and have the Promise chain continue, if
    // you don't care about certain errors or can recover.
});
```

#The Niceties

PromiseKit aims to provide a category analog for all one-time asyncronous features in the iOS SDK (eg. not for UIButton actions, Promises fulfill ***once*** so some parts of the SDK don’t make sense as Promises—as we currently see it anyway).

So far we have:

```objc
#import "PromiseKit+Foundation.h"

[NSURLConnection GET:[NSURL URLWithString:@"http://promisekit.org"]].then(^(NSData *data){
    
}).catch(^(NSError *error){
    NSHTTPURLResponse *rsp = error.userInfo[PMKURLErrorFailingURLResponse];
    int HTTPStatusCode = rsp.statuscode;
});

// Convenience for the common need to create a URL from a string format:
[NSURLConnection GET:@"http://google.com/%@", query].then(…);

// We’re smart, like AFNetworking
[NSURLConnection GET:@"http://google.com" params:@{@"foo": @"bar"}].then(…);

// Should you need to customize the HTTP headers, you can do that too:
NSMutableURLRequest *rq = [NSMutableURLRequest new];
rq.setAllHTTPHeaders = self.headers;
[NSURLConnection promise:rq].then(…);

// PromiseKit reads the response headers and tries to be helpful:

[NSURLConnection GET:@"http://placekitten.org/100/100"].then(^(UIImage *image){
    // Indeed! Pre-converted to a UIImage in a background thread!
});

[NSURLConnection GET:@"http://example.com/some.json"].then(^(NSDictionary *json){
    // Indeed! Pre-deserialized from JSON in a background thread!
});

// otherwise you get the raw `NSData *`



#import "PromiseKit+Foundation.h"

/**
 Sometimes you just want to query the NSURLCache because doing an
 NSURLConnection will take too long and just return the same data anyway. We
 perform the same header analysis as the NSURLConnection categories, so eg. you
 will get back a `UIImage *` or whatever.
**/
[[NSURLCache sharedURLCache] promisedResponseForRequest:rq].then(…)



#import "PromiseKit+CoreLocation.h"

[CLLocationManager promise].then(^(CLLocation *currentUserLocation){
    // If you need the user Location just once, then now you have it
});



#import "PromiseKit+CommonCrypto.h"

[Promise md5:inputString].then(^(NSString *output){
    // MD5 is computed in background thread using CommonCrypto
});



#import "PromiseKit+UIKit.h"

UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"You Didn’t Save!" message: @"You will lose changes." delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Lose Changes", @"Panic", nil];

alert.promise.then(^(NSNumber *dismissedIndex){
    // button that wasn’t cancel was pressed
    // NOTE cancel button DOES NOT trigger catch handler
});


#import "PromiseKit+UIKit.h"

/**
 We provide a pattern for modally presenting ViewControllers:
**/

@implementation MyRootViewController

- (void)foo {
    UIViewController *vc = [MyDetailViewController new];
    [self promiseViewController:vc animated:YES completion:nil].then(^(id result){
        // the result from below in `- (void)someTimeLater`
        // PromiseKit dismisses the MyDetailViewController instance when the
        // Deferred is resolved
    })
}

@end

@implementation MyDetailViewController
@property Deferred *deferred;

- (void)viewWillDefer:(Deferred *)deferMe {
    // Deferred is documented below this section
    _deferred = deferMe;
}

- (void)someTimeLater {
    [_deferred resolve:someResult];
}

@end

```

Note that simply importing `PromiseKit.h` will import everything.


#Deferred

If you want to write your own methods that return Promises then often you will need a `Deferred` object. Promises are deliberately opaque; we don’t want other parts of our codebase modifying their values.

A `Deferred` has a promise, and using a `Deferred` you can set that Promise's value, the Deferred then recursively calls any sub-promises. For example:

```objc
- (Promise *)tenThousandRandomNumbers {
    Deferred *d = [Deferred new];

    dispatch_async(q, ^{
        NSMutableArray *numbers = [NSMutableArray new];
        for (int x = 0; x < 10000; x++)
            [numbers addObject:@(arc4random())];
        dispatch)async(dispatch_get_main_queue(), ^{
            if (logic) {
                [d resolve:numbers];
            } else {
                [d reject:[NSError errorWith…]];
            }
        });
    });

    return d.promise;
}

- (void)viewDidLoad {
    [self tenThousandRandomNumbers].then(^(NSMutableArray *numbers){
        //…
    });
}
```


#The Fine Print

The fine print of PromiseKit is mostly exactly what you would expect, so don’t confuse yourself and only come back here when you find yourself curious about more advanced techniques.

* Returning a Promise as the value of a `then` (or `catch`) handler will cause any subsequent handlers to wait for that Promise to fulfill.
* Returning an instance of `NSError` or throwing an exception within a then block will cause PromiseKit to bubble that object up to the nearest catch handler.
* `catch` handlers always are passed an `NSError` object.
* Returning something other than an `NSError` from a `catch` handler causes PromiseKit to consider the error resolved, and execution will continue at the next `then` handler using the object you returned as the input.
* Not returning from a `catch` handler (or returning nil) causes PromiseKit to consider the Promise complete. No further bubbling occurs.
* Nothing happens if you add a `then` to a failed Promise
* Adding a `catch` handler to a failed Promise will execute that fail handler: this is converse to adding the same to a **pending** Promise.


#Caveats

* We are version 0.9 and thus reserve the right to remove API before 1.0. Probably we won’t, we’re just being cautious.
* PromiseKit is not thread-safe. This is not intentional, we will fix that. Though considering the immutability of Promises, I can’t actually think of an instance where this would be a problem. Really your only concern is to ensure that you return from your `then` handlers in the thread you want subsequent handlers to be run.


#TODO

* Make all categories into optional CocoaPod sub-modules
* Complete categorization of the iOS SDK
