#import "SYPermissions.h"

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@implementation SYPermissions

+ (void)invoke:(SYPermissionHandler)handler granted:(BOOL)granted {
    if (!handler) {
        return;
    }
    // 统一回到主线程：调用方拿到结果后通常要立刻 present 一个控制器。
    if ([NSThread isMainThread]) {
        handler(granted);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(granted);
        });
    }
}

+ (void)requestPhotoLibraryAccess:(SYPermissionHandler)handler {
    PHAuthorizationStatus status;
    if (@available(iOS 14, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
    } else {
        status = [PHPhotoLibrary authorizationStatus];
    }

    switch (status) {
        case PHAuthorizationStatusAuthorized:
            [self invoke:handler granted:YES];
            return;

        case PHAuthorizationStatusNotDetermined: {
            if (@available(iOS 14, *)) {
                [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                           handler:^(PHAuthorizationStatus newStatus) {
                    BOOL granted = newStatus == PHAuthorizationStatusAuthorized ||
                                   newStatus == PHAuthorizationStatusLimited;
                    [self invoke:handler granted:granted];
                }];
            } else {
                [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
                    [self invoke:handler granted:newStatus == PHAuthorizationStatusAuthorized];
                }];
            }
            return;
        }

        default:
            break;
    }

    if (@available(iOS 14, *)) {
        // Limited：用户选择了"仅选中的照片"。他们依然能从中挑选，算已授权。
        if (status == PHAuthorizationStatusLimited) {
            [self invoke:handler granted:YES];
            return;
        }
    }

    // Denied / Restricted
    [self invoke:handler granted:NO];
}

+ (void)requestCameraAccess:(SYPermissionHandler)handler {
    AVAuthorizationStatus status =
        [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    switch (status) {
        case AVAuthorizationStatusAuthorized:
            [self invoke:handler granted:YES];
            return;

        // 必须加大括号：块强捕获了变量，没有独立作用域时无法跳转到后面的 case。
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                     completionHandler:^(BOOL granted) {
                // 关键：拒绝时也必须回调。老实现的 granted == NO 分支是空的，
                // promise 从此永远挂着。
                [self invoke:handler granted:granted];
            }];
            return;
        }

        default:
            [self invoke:handler granted:NO];
            return;
    }
}

@end
