#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// granted 为 NO 时，调用方**必须** reject PERMISSION_DENIED —— 不能只弹个提示
/// 就把 promise 晾在那里（老实现正是这么挂死的）。
typedef void (^SYPermissionHandler)(BOOL granted);

@interface SYPermissions : NSObject

/**
 请求相册访问权限。

 iOS 14 的 Limited（"仅选中的照片"）**按已授权处理** —— 用户确实能选出照片来。
 老实现拿魔数 `== 2` / `== 0` 和授权状态比大小，Limited 既不等于 2 也不等于 0，
 于是落进 else 分支，给了一个莫名其妙的"无权限"提示。
 */
+ (void)requestPhotoLibraryAccess:(SYPermissionHandler)handler;

/// 请求相机权限。
+ (void)requestCameraAccess:(SYPermissionHandler)handler;

@end

NS_ASSUME_NONNULL_END
