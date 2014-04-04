#import "macros.m"
#import "PromiseKit/Deferred.h"
#import "PromiseKit/Promise.h"
#import "PromiseKit+UIKit.h"
@import UIKit.UINavigationController;

@interface PMKMFDeferred : Deferred
@end

@implementation PMKMFDeferred
- (void)mailComposeController:(id)controller didFinishWithResult:(int)result error:(NSError *)error {
    if (error)
        [self reject:error];
    else
        [self resolve:@(result)];
}
@end



@implementation UIViewController (PromiseKit)

- (Promise *)promiseViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void(^)(void))block
{
    [self presentViewController:vc animated:animated completion:block];

    Deferred *d = [Deferred new];

    if ([vc isKindOfClass:[UINavigationController class]])
        vc = [(id)vc viewControllers].firstObject;

    if ([vc isKindOfClass:[NSClassFromString(@"MFMailComposeViewController") class]]) {
        d = [PMKMFDeferred new];
        SEL selector = NSSelectorFromString(@"setMailComposeDelegate:");
        IMP imp = [vc methodForSelector:selector];
        void (*func)(id, SEL, id) = (void *)imp;
        func(vc, selector, d);
    }

    [vc viewWillDefer:d];

    return d.promise.then(^(id o){
        [self dismissViewControllerAnimated:animated completion:nil];
        return o;
    });
}

- (void)viewWillDefer:(Deferred *)deferred {
    NSLog(@"Base implementation of viewWillDefer: called, you probably want to override this.");
}

@end



@interface PMKAlertViewDelegate : Deferred <UIAlertViewDelegate>
@end

@implementation PMKAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [self resolve:@(buttonIndex)];
    __anti_arc_release(self);
}
@end

@implementation UIAlertView (PromiseKit)

- (Promise *)promise {
    PMKAlertViewDelegate *d = [PMKAlertViewDelegate new];
    __anti_arc_retain(d);
    self.delegate = d;
    [self show];
    return d.promise;
}

@end



@implementation UIImageView (PromiseKit)

- (void)promiseImage:(Promise *)promise {
    promise.then(^(UIImage *img){
        self.image = img;
    });
}

@end
