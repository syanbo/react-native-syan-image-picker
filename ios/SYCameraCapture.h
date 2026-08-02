#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SYPickerOptions.h"

NS_ASSUME_NONNULL_BEGIN

/// 三个互斥的结局，每次调用**必定**触发且只触发一次。
typedef void (^SYCameraCompletion)(NSDictionary *_Nullable asset,
                                   NSError *_Nullable error,
                                   BOOL cancelled);

/**
 相机拍摄 / 录像。

 每次调用都会新建一个实例来持有自己的选项与回调，实例自持到流程结束为止。
 老实现把选项挂在模块单例上，结果视频路径读到的是上一次调用残留的值。
 */
@interface SYCameraCapture : NSObject

+ (void)captureImageWithOptions:(SYCaptureImageOptions *)options
                     completion:(SYCameraCompletion)completion;

+ (void)captureVideoWithOptions:(SYCaptureVideoOptions *)options
                     completion:(SYCameraCompletion)completion;

@end

NS_ASSUME_NONNULL_END
