#import "SYPresent.h"

BOOL SYPresenterIsReady(UIViewController *presenter) {
    if (!presenter) {
        return NO;
    }
    if (presenter.isBeingPresented || presenter.isBeingDismissed) {
        return NO;
    }
    if (presenter.transitionCoordinator != nil) {
        return NO;
    }
    if (presenter.view.window == nil) {
        return NO;
    }
    return YES;
}

BOOL SYPresentViewController(UIViewController *presenter,
                             UIViewController *child,
                             NSError **error) {
    if (!SYPresenterIsReady(presenter)) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.syanpicker.present"
                                         code:-1
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : @"找不到可用于展示的控制器"
                                     }];
        }
        return NO;
    }
    @try {
        [presenter presentViewController:child animated:YES completion:nil];
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.syanpicker.present"
                                         code:-1
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : exception.reason ?: @"无法展示界面"
                                     }];
        }
        return NO;
    }
}
