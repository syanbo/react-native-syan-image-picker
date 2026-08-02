#import "SYCameraCapture.h"

#import <React/RCTUtils.h>

#import "SYAssetExporter.h"
#import "SYPermissions.h"

/// UTI 字面量。用常量而不是散落在各处的裸字符串。
static NSString *const kSYUTTypeImage = @"public.image";
static NSString *const kSYUTTypeMovie = @"public.movie";

@interface SYCameraCapture () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, copy) SYCameraCompletion completion;
@property (nonatomic, strong, nullable) SYCaptureImageOptions *imageOptions;
@property (nonatomic, strong, nullable) SYCaptureVideoOptions *videoOptions;
/// 流程进行期间自持，结束时置 nil。
@property (nonatomic, strong, nullable) SYCameraCapture *selfReference;

@end

@implementation SYCameraCapture

#pragma mark - 入口

+ (void)captureImageWithOptions:(SYCaptureImageOptions *)options
                     completion:(SYCameraCompletion)completion {
    SYCameraCapture *capture = [SYCameraCapture new];
    capture.imageOptions = options;
    capture.completion = completion;
    [capture start];
}

+ (void)captureVideoWithOptions:(SYCaptureVideoOptions *)options
                     completion:(SYCameraCompletion)completion {
    SYCameraCapture *capture = [SYCameraCapture new];
    capture.videoOptions = options;
    capture.completion = completion;
    [capture start];
}

#pragma mark - 流程

- (void)start {
    self.selfReference = self;

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        // 模拟器没有相机，走这里而不是抛一个看不懂的崩溃。
        [self finishWithAsset:nil
                        error:[NSError errorWithDomain:@"com.syanpicker.camera"
                                                  code:-1
                                              userInfo:@{
                                                  NSLocalizedDescriptionKey : @"当前设备没有可用的相机"
                                              }]
                    cancelled:NO];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [SYPermissions requestCameraAccess:^(BOOL granted) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (!granted) {
            // 权限被拒也必须有个交代 —— 不能只弹提示就把调用方晾着。
            [self finishWithAsset:nil error:nil cancelled:NO permissionDenied:YES];
            return;
        }
        [self present];
    }];
}

- (void)present {
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    // iOS 13 起默认 pageSheet；相机以 sheet 形式出现既不合预期，也会让
    // allowsEditing 的裁剪界面布局异常。
    picker.modalPresentationStyle = UIModalPresentationFullScreen;

    if (self.videoOptions) {
        picker.mediaTypes = @[ kSYUTTypeMovie ];
        picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
        picker.videoMaximumDuration = self.videoOptions.recordDuration;
    } else {
        picker.mediaTypes = @[ kSYUTTypeImage ];
        // iOS 用系统自带的编辑界面来裁剪；crop 的具体尺寸参数在此不生效，
        // 这一平台差异已在类型定义与 README 中写明。
        picker.allowsEditing = self.imageOptions.crop.enabled;
    }

    UIViewController *presenter = RCTPresentedViewController();
    if (!presenter) {
        [self finishWithAsset:nil
                        error:[NSError errorWithDomain:@"com.syanpicker.camera"
                                                  code:-1
                                              userInfo:@{
                                                  NSLocalizedDescriptionKey : @"找不到可用于展示相机的控制器"
                                              }]
                    cancelled:NO];
        return;
    }
    [presenter presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
    didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES
                               completion:^{
                                   [weakSelf processInfo:info];
                               }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES
                               completion:^{
                                   [weakSelf finishWithAsset:nil error:nil cancelled:YES];
                               }];
}

- (void)processInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    // 编解码一律下沉到后台队列，绝不占用主线程。
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSDictionary *asset = nil;

        if (self.videoOptions) {
            NSURL *url = info[UIImagePickerControllerMediaURL];
            asset = url ? [SYAssetExporter exportVideoAtURL:url error:&error] : nil;
        } else {
            UIImage *image = info[UIImagePickerControllerEditedImage]
                                 ?: info[UIImagePickerControllerOriginalImage];
            // 相机没有 PHAsset，原始字节只能从源文件 URL 拿（系统并不保证提供）。
            // 用了系统编辑界面（allowsEditing）时图片已被裁剪，不能再用原始字节。
            NSURL *sourceURL = info[UIImagePickerControllerImageURL];
            BOOL cropped = self.imageOptions.crop.enabled;

            asset = [SYAssetExporter exportImage:image
                                           asset:nil
                                       sourceURL:sourceURL
                                        compress:self.imageOptions.compress
                                   includeBase64:self.imageOptions.includeBase64
                               allowOriginalData:!cropped
                               originalRequested:NO
                                    keepOriginal:self.imageOptions.keepOriginal
                                           error:&error];
        }

        [self finishWithAsset:asset error:asset ? nil : error cancelled:NO];
    });
}

#pragma mark - 结算

- (void)finishWithAsset:(nullable NSDictionary *)asset
                  error:(nullable NSError *)error
              cancelled:(BOOL)cancelled {
    [self finishWithAsset:asset error:error cancelled:cancelled permissionDenied:NO];
}

- (void)finishWithAsset:(nullable NSDictionary *)asset
                  error:(nullable NSError *)error
              cancelled:(BOOL)cancelled
       permissionDenied:(BOOL)permissionDenied {
    SYCameraCompletion completion = self.completion;
    self.completion = nil; // 幂等：只可能结算一次。
    self.selfReference = nil;

    if (!completion) {
        return;
    }
    if (permissionDenied) {
        completion(nil,
                   [NSError errorWithDomain:@"com.syanpicker.permission"
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey : @"用户拒绝了相机权限"}],
                   NO);
        return;
    }
    completion(asset, error, cancelled);
}

@end
