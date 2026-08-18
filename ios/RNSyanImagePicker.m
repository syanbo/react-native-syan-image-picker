#import "RNSyanImagePicker.h"

#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <React/RCTUtils.h>
#import <TZImagePickerController/TZImagePickerController.h>

#import "SYAssetExporter.h"
#import "SYCameraCapture.h"
#import "SYPermissions.h"
#import "SYPickerOptions.h"
#import "SYPresent.h"
#import "SYPreview.h"
#import "SYRequestGate.h"

/// 与 TS 侧 SyanErrorCode 一一对应。
static NSString *const kSYCodePermissionDenied = @"PERMISSION_DENIED";
static NSString *const kSYCodeExportFailed = @"EXPORT_FAILED";
static NSString *const kSYCodeUnsupported = @"UNSUPPORTED";
static NSString *const kSYCodeBusy = @"BUSY";

/// 标记某个 picker 是否已经被关闭过，避免重复 dismiss 把 completion 吞掉。
static const void *kSYPickerDismissedKey = &kSYPickerDismissedKey;

/// 与 TS 侧 SY_PROGRESS_EVENT 必须一致。
static NSString *const kSYProgressEvent = @"RNSyanImagePicker:progress";

@interface RNSyanImagePicker ()
/// 有没有人在监听进度。没人听就一条事件也不发。
@property (nonatomic, assign) BOOL hasProgressListeners;
/** 当前占用原生展示通道的请求；请求令牌可防止迟到回调误释放新请求。 */
@property (nonatomic, strong) SYRequestGate *requestGate;
@end

@implementation RNSyanImagePicker

RCT_EXPORT_MODULE()

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestGate = [SYRequestGate new];
    }
    return self;
}

#pragma mark - 请求串行化

- (nullable NSObject *)beginModalRequestWithReject:(RCTPromiseRejectBlock)reject {
    NSObject *token = [self.requestGate begin];
    if (!token) {
        reject(kSYCodeBusy, @"选择器正在使用中", nil);
    }
    return token;
}

- (RCTPromiseResolveBlock)guardedResolveForToken:(NSObject *)token
                                         resolve:(RCTPromiseResolveBlock)resolve {
    return ^(id result) {
        if ([self.requestGate finish:token]) {
            resolve(result);
        }
    };
}

- (RCTPromiseRejectBlock)guardedRejectForToken:(NSObject *)token
                                        reject:(RCTPromiseRejectBlock)reject {
    return ^(NSString *code, NSString *message, NSError *error) {
        if ([self.requestGate finish:token]) {
            reject(code, message, error);
        }
    };
}

#pragma mark - 进度事件

- (NSArray<NSString *> *)supportedEvents {
    return @[ kSYProgressEvent ];
}

- (void)startObserving {
    self.hasProgressListeners = YES;
}

- (void)stopObserving {
    self.hasProgressListeners = NO;
}

/// 发一条进度。无人监听时直接返回 —— RCTEventEmitter 在没有监听者时发送会告警。
- (void)emitProgressPhase:(NSString *)phase
                completed:(NSUInteger)completed
                    total:(NSUInteger)total {
    if (!self.hasProgressListeners) {
        return;
    }
    [self sendEventWithName:kSYProgressEvent
                       body:@{
                           @"phase" : phase,
                           @"completed" : @(completed),
                           @"total" : @(total),
                       }];
}

/**
 停留在主队列，因为 present / dismiss 必须在主线程。

 但**所有**编解码、写盘、base64 都会显式派发到后台队列 —— 老实现同样把
 methodQueue 设成主队列，却把 JPEG 编码和 base64 也留在了上面，多选大图必卡。
 */
- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

/// 本库自己的处理队列，串行以保证结果顺序与选择顺序一致。
- (dispatch_queue_t)workQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.syanpicker.work", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

#pragma mark - 结果构造

static NSDictionary *SYCancelledResult(void) {
    return @{@"cancelled" : @YES, @"assets" : @[]};
}

static NSDictionary *SYSuccessResult(NSArray *assets) {
    return @{@"cancelled" : @NO, @"assets" : assets ?: @[]};
}

#pragma mark - 处理期间的原生 HUD

/**
 让选择器停在原地转圈，处理完再退出。

 TZ 默认 autoDismiss=YES —— 先关 HUD、再 dismiss、最后才回调我们，于是我们所有
 的导出工作都发生在选择器消失之后，用户看到的是自己的界面毫无反应（视频导出可能
 几十秒）。把 autoDismiss 设成 NO 之后，回调时选择器还在，就能复用 TZ 自己的 HUD
 把这段等待盖住 —— 与 Android 的行为对齐（PictureSelector 在压缩阶段本来就有 loading）。

 代价：**关闭责任全部转移到我们身上**。下面这个方法是唯一的收尾出口，
 每条分支都必须走它，否则选择器会永远停在屏幕上。
 */
- (void)finishPicker:(TZImagePickerController *)picker
         showLoading:(BOOL)showLoading
          completion:(dispatch_block_t)completion {
    dispatch_block_t finish = ^{
        /*
         关键：picker 可能**已经被关掉了**。

         showLoading: NO 时 beginProcessing: 就立刻 dismiss 了，等导出结束走到这里，
         weak 的 picker 已经是 nil。而 resolve/reject 是挂在 dismiss 的 completion
         上的 —— 对 nil 发消息是空操作，completion 永不执行，promise 就永久挂起。

         所以这里必须先判断：已经关过（或已释放）就直接结算。
         */
        if (!picker || [objc_getAssociatedObject(picker, kSYPickerDismissedKey) boolValue]) {
            if (completion) {
                completion();
            }
            return;
        }

        objc_setAssociatedObject(picker, kSYPickerDismissedKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (showLoading) {
            [picker hideProgressHUD];
        }
        [picker dismissViewControllerAnimated:YES
                                   completion:^{
                                       if (completion) {
                                           completion();
                                       }
                                   }];
    };
    if ([NSThread isMainThread]) {
        finish();
    } else {
        dispatch_async(dispatch_get_main_queue(), finish);
    }
}

/// 开始处理：把 HUD 打起来（必须在主线程）。
- (void)beginProcessing:(TZImagePickerController *)picker showLoading:(BOOL)showLoading {
    if (!showLoading) {
        // 不显示 HUD 就立刻退出，处理在后台静默进行。
        // 必须打标记：否则 finishPicker: 还会再关一次，而那次的 completion
        // （里面才是 resolve/reject）根本不会被调用。
        objc_setAssociatedObject(picker, kSYPickerDismissedKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [picker dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [picker showProgressHUD];
}

#pragma mark - 相册：图片

RCT_EXPORT_METHOD(pickImage
                  : (NSDictionary *)options resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
    SYImageOptions *opts = [SYImageOptions fromDictionary:options];
    NSObject *token = [self beginModalRequestWithReject:reject];
    if (!token) {
        return;
    }
    RCTPromiseResolveBlock guardedResolve =
        [self guardedResolveForToken:token resolve:resolve];
    RCTPromiseRejectBlock guardedReject =
        [self guardedRejectForToken:token reject:reject];

    [SYPermissions requestPhotoLibraryAccess:^(BOOL granted) {
        if (!granted) {
            guardedReject(kSYCodePermissionDenied, @"用户拒绝了相册访问权限", nil);
            return;
        }
        [self presentImagePickerWithOptions:opts
                                    resolve:guardedResolve
                                     reject:guardedReject];
    }];
}

- (void)presentImagePickerWithOptions:(SYImageOptions *)opts
                              resolve:(RCTPromiseResolveBlock)resolve
                               reject:(RCTPromiseRejectBlock)reject {
    TZImagePickerController *picker =
        [[TZImagePickerController alloc] initWithMaxImagesCount:opts.maxCount delegate:nil];

    picker.minImagesCount = opts.minCount;
    picker.allowPickingImage = YES;
    picker.allowPickingVideo = NO;
    picker.allowPickingGif = opts.allowGif;
    /*
     允许 GIF 时必须同时打开 allowPickingMultipleVideo（旧实现就是这么做的）。

     否则 TZ 不给 GIF 单元格渲染选择框，用户只能点进去，被路由到
     TZGifPhotoPreviewController —— 那个页面的"完成"只调
     didFinishPickingGifImageHandle，而我们从不安装该回调；叠加 autoDismiss = NO，
     结果是按钮点了没反应、选择器卡在全屏、promise 永不结算。
     打开它之后 GIF 走的是与普通图片相同的多选通道。
     */
    picker.allowPickingMultipleVideo = opts.allowGif;
    picker.allowPickingOriginalPhoto = opts.allowOriginal;
    picker.allowTakePicture = opts.showCameraButton;
    picker.sortAscendingByModificationDate = opts.sortAscending;
    picker.showSelectedIndex = opts.showSelectionIndex;
    picker.selectedAssets = [self selectedAssetsForURIs:opts.selectedUris];

    // 裁剪只在单选时有意义。
    BOOL shouldCrop = opts.crop.enabled && opts.maxCount == 1;
    picker.allowCrop = shouldCrop;
    if (shouldCrop) {
        /*
         裁剪界面只在 TZPhotoPreviewController.configCropView 里构建，
         而进入预览页的前提是网格上没有"选择框 + 完成"这条捷径。
         不设 showSelectBtn = NO 的话，用户可以直接勾选并点完成，
         裁剪被完全绕过，调用方明明请求了 300x300 却拿回整幅原图且毫无提示。
         旧实现在单选分支正是这么设的。
         */
        picker.showSelectBtn = NO;
        picker.needCircleCrop = opts.crop.circle;
        picker.circleCropRadius = MIN(opts.crop.width, opts.crop.height) / 2;
        picker.cropRect = [self cropRectForWidth:opts.crop.width height:opts.crop.height];
    }

    SYCompressOptions *compress = opts.compress;
    BOOL includeBase64 = opts.includeBase64;
    NSInteger minFileSize = opts.minFileSize;
    NSInteger maxFileSize = opts.maxFileSize;
    BOOL keepOriginal = opts.keepOriginal;
    BOOL showLoading = opts.showLoading;
    BOOL allowGif = opts.allowGif;

    /*
     关掉 autoDismiss，让选择器停在原地等我们处理完。
     注意：取消路径同样受它控制（TZ 的 cancelButtonClick 也判断 autoDismiss），
     所以**取消也必须由我们关闭**，见下面的 wrappedResolve / 取消回调。
     */
    picker.autoDismiss = NO;

    // 每次调用一份独立的结算守卫：无论走到哪条分支，promise 只会被结算一次，
    // 且**每条**分支都必须结算 —— 老实现里有好几条路径静默地什么都不做。
    __block BOOL settled = NO;
    NSObject *lock = [NSObject new];
    BOOL (^claim)(void) = ^BOOL {
        @synchronized(lock) {
            if (settled) {
                return NO;
            }
            settled = YES;
            return YES;
        }
    };

    __weak typeof(self) weakSelf = self;
    // picker 用 weak：这些 block 是挂在 picker 上的，强引用会成环。
    __weak TZImagePickerController *weakPicker = picker;

    // 所有结算都先收尾（关 HUD + dismiss），再回调 JS。
    RCTPromiseResolveBlock wrappedResolve = ^(id result) {
        [weakSelf finishPicker:weakPicker
                   showLoading:showLoading
                    completion:^{
                        resolve(result);
                    }];
    };
    RCTPromiseRejectBlock wrappedReject =
        ^(NSString *code, NSString *message, NSError *error) {
            [weakSelf finishPicker:weakPicker
                       showLoading:showLoading
                        completion:^{
                            reject(code, message, error);
                        }];
        };

    picker.didFinishPickingPhotosWithInfosHandle =
        ^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto,
          NSArray<NSDictionary *> *infos) {
            if (!claim()) {
                return;
            }
            [weakSelf beginProcessing:weakPicker showLoading:showLoading];
            [weakSelf exportPhotos:photos
                             assets:assets
                           compress:compress
                      includeBase64:includeBase64
                  allowOriginalData:!shouldCrop
                  originalRequested:isSelectOriginalPhoto
                        minFileSize:minFileSize
                        maxFileSize:maxFileSize
                       keepOriginal:keepOriginal
                           allowGif:allowGif
                            resolve:wrappedResolve
                             reject:wrappedReject];
        };

    picker.imagePickerControllerDidCancelHandle = ^{
        if (!claim()) {
            return;
        }
        // 取消不是错误。autoDismiss=NO 时取消也不会自动关闭，必须走收尾。
        [weakSelf finishPicker:weakPicker
                   showLoading:NO
                    completion:^{
                        resolve(SYCancelledResult());
                    }];
    };

    [self presentPicker:picker claim:claim reject:reject];
}

- (void)exportPhotos:(NSArray<UIImage *> *)photos
               assets:(NSArray *)assets
             compress:(SYCompressOptions *)compress
        includeBase64:(BOOL)includeBase64
    allowOriginalData:(BOOL)allowOriginalData
    originalRequested:(BOOL)originalRequested
          minFileSize:(NSInteger)minFileSize
          maxFileSize:(NSInteger)maxFileSize
         keepOriginal:(BOOL)keepOriginal
             allowGif:(BOOL)allowGif
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject {
    dispatch_async([self workQueue], ^{
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:photos.count];

        // 按下标顺序串行处理 —— 结果顺序天然等于选择顺序。老的 iOS 实现用多个
        // 异步回调往同一个可变数组里追加，顺序是乱的，还有数据竞争。
        for (NSUInteger index = 0; index < photos.count; index++) {
            PHAsset *asset = index < assets.count ? assets[index] : nil;

            // TZ 无法在选择界面内按文件大小筛选，只能选完之后剔除。
            // 与 video.maxDuration 在 iOS 上是同一种处理方式，已写入 README。
            if (![self asset:asset fitsMinSize:minFileSize maxSize:maxFileSize]) {
                continue;
            }

            /*
             allowGif: NO 时剔除 GIF。

             这是两端语义对齐所必需的：Android 在查询层过滤，GIF 根本不出现；
             而 TZ 的 allowPickingGif=NO **并不隐藏 GIF**，只是"把它当作普通图片"
             （见其头文件注释），用户照样能选中。不在这里剔除的话，一个明确
             声明了不要 GIF 的调用方还是会拿到 GIF 文件 —— 尤其在我们已经让
             GIF 走原始字节透传之后，返回的就是货真价实的 .gif。
             */
            if (!allowGif && [self isGifAsset:asset]) {
                continue;
            }

            NSError *error = nil;
            NSDictionary *item = [SYAssetExporter exportImage:photos[index]
                                                        asset:asset
                                                    sourceURL:nil
                                                     compress:compress
                                                includeBase64:includeBase64
                                            allowOriginalData:allowOriginalData
                                            originalRequested:originalRequested
                                                 keepOriginal:keepOriginal
                                                        error:&error];
            if (!item) {
                reject(kSYCodeExportFailed,
                       error.localizedDescription ?: @"图片导出失败", error);
                return;
            }
            [results addObject:item];
            [self emitProgressPhase:@"processing"
                          completed:index + 1
                              total:photos.count];
        }

        resolve(SYSuccessResult(results));
    });
}

#pragma mark - 相册：视频

RCT_EXPORT_METHOD(pickVideo
                  : (NSDictionary *)options resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
    SYVideoOptions *opts = [SYVideoOptions fromDictionary:options];
    NSObject *token = [self beginModalRequestWithReject:reject];
    if (!token) {
        return;
    }
    RCTPromiseResolveBlock guardedResolve =
        [self guardedResolveForToken:token resolve:resolve];
    RCTPromiseRejectBlock guardedReject =
        [self guardedRejectForToken:token reject:reject];

    [SYPermissions requestPhotoLibraryAccess:^(BOOL granted) {
        if (!granted) {
            guardedReject(kSYCodePermissionDenied, @"用户拒绝了相册访问权限", nil);
            return;
        }
        [self presentVideoPickerWithOptions:opts
                                    resolve:guardedResolve
                                     reject:guardedReject];
    }];
}

- (void)presentVideoPickerWithOptions:(SYVideoOptions *)opts
                              resolve:(RCTPromiseResolveBlock)resolve
                               reject:(RCTPromiseRejectBlock)reject {
    TZImagePickerController *picker =
        [[TZImagePickerController alloc] initWithMaxImagesCount:opts.maxCount delegate:nil];

    picker.minImagesCount = opts.minCount;
    picker.allowPickingImage = NO;
    picker.allowPickingVideo = YES;
    picker.allowPickingGif = NO;
    // 打开多选视频后，结果统一从 photos 回调出来，只需维护一条导出路径。
    picker.allowPickingMultipleVideo = YES;
    picker.allowTakeVideo = opts.showCameraButton;
    picker.sortAscendingByModificationDate = opts.sortAscending;
    picker.selectedAssets = [self selectedAssetsForURIs:opts.selectedUris];

    /*
     注意：videoMaximumDuration 是选择器内**录制**视频的时长上限，不是相册里
     可选视频的筛选条件 —— TZImagePickerController 根本没有按时长筛选的能力
     （3.8.x 的头文件里不存在任何 min/max duration 筛选属性）。
     这里把录制上限对齐到 maxDuration，让录出来的视频天然满足约束；
     从相册选中的视频则在结果返回前统一过滤（见 exportVideoAssets:）。
     */
    if (opts.maxDuration > 0) {
        picker.videoMaximumDuration = opts.maxDuration;
    }

    NSInteger minDuration = opts.minDuration;
    NSInteger maxDuration = opts.maxDuration;
    NSInteger minFileSize = opts.minFileSize;
    NSInteger maxFileSize = opts.maxFileSize;
    BOOL transcode = opts.transcode;
    BOOL showLoading = opts.showLoading;

    // 同图片路径：关掉 autoDismiss，收尾责任转移到我们身上。
    picker.autoDismiss = NO;

    __block BOOL settled = NO;
    NSObject *lock = [NSObject new];
    BOOL (^claim)(void) = ^BOOL {
        @synchronized(lock) {
            if (settled) {
                return NO;
            }
            settled = YES;
            return YES;
        }
    };

    __weak typeof(self) weakSelf = self;
    __weak TZImagePickerController *weakPicker = picker;

    RCTPromiseResolveBlock wrappedResolve = ^(id result) {
        [weakSelf finishPicker:weakPicker
                   showLoading:showLoading
                    completion:^{
                        resolve(result);
                    }];
    };
    RCTPromiseRejectBlock wrappedReject =
        ^(NSString *code, NSString *message, NSError *error) {
            [weakSelf finishPicker:weakPicker
                       showLoading:showLoading
                        completion:^{
                            reject(code, message, error);
                        }];
        };

    picker.didFinishPickingPhotosWithInfosHandle =
        ^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto,
          NSArray<NSDictionary *> *infos) {
            if (!claim()) {
                return;
            }
            [weakSelf beginProcessing:weakPicker showLoading:showLoading];
            [weakSelf exportVideoAssets:assets
                                 covers:photos
                            minDuration:minDuration
                            maxDuration:maxDuration
                            minFileSize:minFileSize
                            maxFileSize:maxFileSize
                              transcode:transcode
                                resolve:wrappedResolve
                                 reject:wrappedReject];
        };

    // 兜底：万一 TZ 走了单选视频回调，这里同样能结算，不会挂死。
    picker.didFinishPickingVideoHandle = ^(UIImage *coverImage, PHAsset *asset) {
        if (!claim()) {
            return;
        }
        [weakSelf beginProcessing:weakPicker showLoading:showLoading];
        [weakSelf exportVideoAssets:asset ? @[ asset ] : @[]
                             covers:coverImage ? @[ coverImage ] : @[]
                        minDuration:minDuration
                        maxDuration:maxDuration
                        minFileSize:minFileSize
                        maxFileSize:maxFileSize
                          transcode:transcode
                            resolve:wrappedResolve
                             reject:wrappedReject];
    };

    picker.imagePickerControllerDidCancelHandle = ^{
        if (!claim()) {
            return;
        }
        [weakSelf finishPicker:weakPicker
                   showLoading:NO
                    completion:^{
                        resolve(SYCancelledResult());
                    }];
    };

    [self presentPicker:picker claim:claim reject:reject];
}

- (void)exportVideoAssets:(NSArray *)assets
                   covers:(NSArray<UIImage *> *)covers
              minDuration:(NSInteger)minDuration
              maxDuration:(NSInteger)maxDuration
              minFileSize:(NSInteger)minFileSize
              maxFileSize:(NSInteger)maxFileSize
                transcode:(BOOL)transcode
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject {
    dispatch_async([self workQueue], ^{
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:assets.count];

        for (NSUInteger index = 0; index < assets.count; index++) {
            id asset = assets[index];
            if (![asset isKindOfClass:[PHAsset class]]) {
                continue;
            }

            // TZ 无法在选择界面内按时长筛选，只能在这里剔除不满足约束的视频。
            // 该行为已写入 README 的平台差异表。
            NSTimeInterval duration = [(PHAsset *)asset duration];
            if (duration < minDuration || (maxDuration > 0 && duration > maxDuration)) {
                continue;
            }
            if (![self asset:asset fitsMinSize:minFileSize maxSize:maxFileSize]) {
                continue;
            }

            UIImage *cover = index < covers.count ? covers[index] : nil;
            NSError *error = nil;
            NSDictionary *item = [SYAssetExporter exportVideoForAsset:asset
                                                           coverImage:cover
                                                            transcode:transcode
                                                                error:&error];
            if (!item) {
                // 导出失败必须 reject。老实现这里是个空的 failure 块，
                // promise 和 HUD 会一起永久卡住。
                reject(kSYCodeExportFailed,
                       error.localizedDescription ?: @"视频导出失败", error);
                return;
            }
            [results addObject:item];
            [self emitProgressPhase:@"exporting"
                          completed:index + 1
                              total:assets.count];
        }

        resolve(SYSuccessResult(results));
    });
}

#pragma mark - 相机

RCT_EXPORT_METHOD(captureImage
                  : (NSDictionary *)options resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
    SYCaptureImageOptions *opts = [SYCaptureImageOptions fromDictionary:options];
    NSObject *token = [self beginModalRequestWithReject:reject];
    if (!token) {
        return;
    }
    RCTPromiseResolveBlock guardedResolve =
        [self guardedResolveForToken:token resolve:resolve];
    RCTPromiseRejectBlock guardedReject =
        [self guardedRejectForToken:token reject:reject];
    [SYCameraCapture captureImageWithOptions:opts
                                  completion:^(NSDictionary *asset, NSError *error, BOOL cancelled) {
                                      [self settleCapture:asset
                                                    error:error
                                                cancelled:cancelled
                                                  resolve:guardedResolve
                                                   reject:guardedReject];
                                  }];
}

RCT_EXPORT_METHOD(captureVideo
                  : (NSDictionary *)options resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
    SYCaptureVideoOptions *opts = [SYCaptureVideoOptions fromDictionary:options];
    NSObject *token = [self beginModalRequestWithReject:reject];
    if (!token) {
        return;
    }
    RCTPromiseResolveBlock guardedResolve =
        [self guardedResolveForToken:token resolve:resolve];
    RCTPromiseRejectBlock guardedReject =
        [self guardedRejectForToken:token reject:reject];
    [SYCameraCapture captureVideoWithOptions:opts
                                  completion:^(NSDictionary *asset, NSError *error, BOOL cancelled) {
                                      [self settleCapture:asset
                                                    error:error
                                                cancelled:cancelled
                                                  resolve:guardedResolve
                                                   reject:guardedReject];
                                  }];
}

- (void)settleCapture:(NSDictionary *)asset
                error:(NSError *)error
            cancelled:(BOOL)cancelled
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject {
    if (cancelled) {
        resolve(SYCancelledResult());
        return;
    }
    if (error) {
        NSString *code = kSYCodeExportFailed;
        if ([error.domain isEqualToString:@"com.syanpicker.permission"]) {
            code = kSYCodePermissionDenied;
        } else if ([error.domain isEqualToString:@"com.syanpicker.camera"]) {
            code = kSYCodeUnsupported;
        }
        reject(code, error.localizedDescription, error);
        return;
    }
    resolve(SYSuccessResult(asset ? @[ asset ] : @[]));
}

#pragma mark - 预览

RCT_EXPORT_METHOD(openPreview
                  : (NSDictionary *)options resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
    NSArray *rawUris = [options isKindOfClass:[NSDictionary class]] ? options[@"uris"] : nil;
    NSInteger index = [options[@"index"] isKindOfClass:[NSNumber class]]
                          ? [options[@"index"] integerValue]
                          : 0;

    if (![rawUris isKindOfClass:[NSArray class]] || rawUris.count == 0) {
        resolve([NSNull null]);
        return;
    }

    NSObject *token = [self beginModalRequestWithReject:reject];
    if (!token) {
        return;
    }
    RCTPromiseResolveBlock guardedResolve =
        [self guardedResolveForToken:token resolve:resolve];
    RCTPromiseRejectBlock guardedReject =
        [self guardedRejectForToken:token reject:reject];

    // 解码放后台，present 回主线程。
    dispatch_async([self workQueue], ^{
        NSMutableArray<UIImage *> *photos = [NSMutableArray array];
        for (id item in rawUris) {
            if (![item isKindOfClass:[NSString class]]) {
                continue;
            }
            NSURL *url = [NSURL URLWithString:item];
            NSString *path = url.isFileURL ? url.path : item;
            UIImage *image = [UIImage imageWithContentsOfFile:path];
            if (image) {
                [photos addObject:image];
            }
        }

        if (photos.count == 0) {
            guardedReject(kSYCodeExportFailed, @"没有可预览的有效文件", nil);
            return;
        }

        NSInteger clamped = MIN(MAX(index, 0), (NSInteger)photos.count - 1);

        dispatch_async(dispatch_get_main_queue(), ^{
            // 不能走 TZ 的 initWithSelectedAssets:selectedPhotos:index:。
            // 那个入口用 selectedAssets 填 models；我们只有缓存文件 UIImage，
            // 传空 assets 会在 refreshNaviBarAndBottomBarState 里对 models[index]
            // 越界崩溃。
            SYPreviewController *previewVc =
                [[SYPreviewController alloc] initWithImages:photos startIndex:clamped];

            UIViewController *presenter = RCTPresentedViewController();
            NSError *error = nil;
            if (!SYPresenterIsReady(presenter) ||
                !SYPresentViewController(presenter, previewVc, &error)) {
                guardedReject(kSYCodeUnsupported,
                              error.localizedDescription ?: @"找不到可用于展示预览的控制器",
                              error);
                return;
            }
            // 与 Android 一致：展示成功即 resolve，不等用户关闭。
            guardedResolve([NSNull null]);
        });
    });
}

#pragma mark - 缓存

RCT_EXPORT_METHOD(clearCache
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
    dispatch_async([self workQueue], ^{
        [SYAssetExporter clearCache];
        resolve([NSNull null]);
    });
}

#pragma mark - 工具

- (void)presentPicker:(TZImagePickerController *)picker
                claim:(BOOL (^)(void))claim
               reject:(RCTPromiseRejectBlock)reject {
    /*
     必须强制全屏。

     iOS 13 起模态展示默认是 pageSheet，而裁剪框的坐标是按 [UIScreen mainScreen]
     的完整尺寸算的（见 cropRectForWidth:height:）—— 在 sheet 里就会偏移甚至超出
     选择器边界，iPad 上尤其明显。TZImagePickerController 自己只对视频裁剪控制器
     设了 FullScreen，选择器本身没设。
     */
    picker.modalPresentationStyle = UIModalPresentationFullScreen;

    UIViewController *presenter = RCTPresentedViewController();
    NSError *error = nil;
    if (!SYPresenterIsReady(presenter) || !SYPresentViewController(presenter, picker, &error)) {
        if (claim()) {
            reject(kSYCodeUnsupported,
                   error.localizedDescription ?: @"找不到可用于展示选择器的控制器",
                   error);
        }
        return;
    }
}

/**
 源文件大小是否落在 [minKB, maxKB] 内。两个上下限都为 0 时直接放行，
 避免为不需要筛选的调用平白多做一次 IO。
 */
- (BOOL)asset:(PHAsset *)asset
    fitsMinSize:(NSInteger)minKB
        maxSize:(NSInteger)maxKB {
    if (minKB <= 0 && maxKB <= 0) {
        return YES;
    }
    long long bytes = [SYAssetExporter sourceFileSizeForAsset:asset];
    if (bytes < 0) {
        return YES; // 取不到大小就不拦，宁可放过也不误杀
    }
    long long kb = bytes / 1024;
    if (minKB > 0 && kb < minKB) {
        return NO;
    }
    if (maxKB > 0 && kb > maxKB) {
        return NO;
    }
    return YES;
}

/// 判断资源是否为 GIF。只对已选中的少数资源调用，成本可接受。
- (BOOL)isGifAsset:(PHAsset *)asset {
    if (!asset) {
        return NO;
    }
    PHAssetResource *resource = [PHAssetResource assetResourcesForAsset:asset].firstObject;
    NSString *uti = resource.uniformTypeIdentifier;
    if ([uti isEqualToString:@"com.compuserve.gif"]) {
        return YES;
    }
    return [[resource.originalFilename.pathExtension lowercaseString] isEqualToString:@"gif"];
}

- (CGRect)cropRectForWidth:(NSInteger)width height:(NSInteger)height {
    CGSize screen = [UIScreen mainScreen].bounds.size;
    CGFloat x = (screen.width - width) / 2.0;
    CGFloat y = (screen.height - height) / 2.0;
    return CGRectMake(x, y, width, height);
}

/// 把上次返回的 uri 还原成 PHAsset，用于回填选中态。
- (NSMutableArray *)selectedAssetsForURIs:(NSArray<NSString *> *)uris {
    NSMutableArray *assets = [NSMutableArray array];
    if (uris.count == 0) {
        return assets;
    }
    // JS 层传过来的优先是结果里的 assetId，也就是 PHAsset.localIdentifier；
    // 结果中的 uri 指向缓存目录里的产物文件，无法反查回相册资源。
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (NSString *uri in uris) {
        if ([uri hasPrefix:@"file://"]) {
            continue; // 文件路径无法还原成 PHAsset，跳过。
        }
        [identifiers addObject:[uri hasPrefix:@"ph://"] ? [uri substringFromIndex:5] : uri];
    }
    if (identifiers.count == 0) {
        return assets;
    }
    PHFetchResult<PHAsset *> *result =
        [PHAsset fetchAssetsWithLocalIdentifiers:identifiers options:nil];
    [result enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
        [assets addObject:asset];
    }];
    return assets;
}

@end
