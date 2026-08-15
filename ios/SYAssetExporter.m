#import "SYAssetExporter.h"

#import <AVFoundation/AVFoundation.h>
#import <TZImagePickerController/TZImageManager.h>

#import "SYCompressPlan.h"
#import "SYImageCodec.h"

static NSString *const kSYCacheDirName = @"syan-image-picker";
static NSString *const kSYErrorDomain = @"com.syanpicker.export";

/// 视频导出的兜底超时。宁可报错，也不要让调用方永远等下去。
static const NSTimeInterval kSYVideoExportTimeout = 180.0;

@implementation SYAssetExporter

#pragma mark - 缓存

+ (NSString *)cacheDirectory {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:kSYCacheDirName];
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:dir]) {
        NSError *error = nil;
        [manager createDirectoryAtPath:dir
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&error];
        if (error) {
            NSLog(@"[RNSyanImagePicker] 创建缓存目录失败: %@", error);
        }
    }
    return dir;
}

+ (void)clearCache {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *dir = [self cacheDirectory];
    NSError *error = nil;
    NSArray<NSString *> *contents = [manager contentsOfDirectoryAtPath:dir error:&error];
    for (NSString *name in contents) {
        [manager removeItemAtPath:[dir stringByAppendingPathComponent:name] error:NULL];
    }
}

#pragma mark - 工具

+ (NSError *)errorWithMessage:(NSString *)message {
    return [NSError errorWithDomain:kSYErrorDomain
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey : message ?: @"导出失败"}];
}

/**
 取原始文件名。

 用公开的 PHAssetResource API —— 老实现走的是 `[asset valueForKey:@"filename"]`，
 那是对 PHAsset **私有属性**的 KVC，既可能返回 nil 也有 App Review 风险。
 */
+ (nullable NSString *)originalFileNameForAsset:(nullable PHAsset *)asset {
    if (!asset) {
        return nil;
    }
    NSArray<PHAssetResource *> *resources = [PHAssetResource assetResourcesForAsset:asset];
    return resources.firstObject.originalFilename;
}

+ (NSString *)uniqueFileNameWithExtension:(NSString *)extension {
    return [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], extension];
}

/// base64 失败时返回 nil，调用方直接省略该字段，绝不返回半截数据。
+ (nullable NSString *)base64ForData:(NSData *)data {
    if (data.length == 0) {
        return nil;
    }
    return [data base64EncodedStringWithOptions:0];
}

#pragma mark - 图片

+ (long long)sourceFileSizeForAsset:(PHAsset *)asset {
    if (!asset) {
        return -1;
    }

    __block long long size = -1;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    PHContentEditingInputRequestOptions *options =
        [PHContentEditingInputRequestOptions new];
    options.networkAccessAllowed = YES; // iCloud 照片

    [asset requestContentEditingInputWithOptions:options
                              completionHandler:^(PHContentEditingInput *input,
                                                  NSDictionary *info) {
        NSURL *url = input.fullSizeImageURL;
        if (!url && [input.audiovisualAsset isKindOfClass:[AVURLAsset class]]) {
            url = [(AVURLAsset *)input.audiovisualAsset URL];
        }
        if (url.isFileURL) {
            NSNumber *fileSize = [[NSFileManager defaultManager]
                attributesOfItemAtPath:url.path
                                 error:NULL][NSFileSize];
            if (fileSize) {
                size = fileSize.longLongValue;
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];

    // 带超时：iCloud 下载可能很慢，绝不能把工作队列永久堵死。
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(semaphore, deadline) != 0) {
        return -1;
    }
    return size;
}

/// 同步取相册中的原始字节。必须在后台队列调用（synchronous = YES）。
+ (nullable NSData *)originalDataForAsset:(PHAsset *)asset {
    if (!asset) {
        return nil;
    }
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.synchronous = YES;
    options.networkAccessAllowed = YES; // iCloud 照片
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;

    __block NSData *result = nil;
    if (@available(iOS 13, *)) {
        [[PHImageManager defaultManager]
            requestImageDataAndOrientationForAsset:asset
                                          options:options
                                    resultHandler:^(NSData *imageData, NSString *dataUTI,
                                                    CGImagePropertyOrientation orientation,
                                                    NSDictionary *info) {
                                        result = imageData;
                                    }];
    } else {
        // iOS 13 以下只有这个 API，属于刻意保留的兼容分支（本库支持到 iOS 11）。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[PHImageManager defaultManager]
            requestImageDataForAsset:asset
                             options:options
                       resultHandler:^(NSData *imageData, NSString *dataUTI,
                                       UIImageOrientation orientation, NSDictionary *info) {
                           result = imageData;
                       }];
#pragma clang diagnostic pop
    }
    return result;
}

/**
 按压缩计划算出目标**长边**像素数，0 表示不缩放。

 自动模式用 [SYCompressPlan autoSampleSizeForWidth:height:]（2 的幂倍率），
 手动模式用边界框。两者都与 Android 的 CompressPlan 一一对应。
 */
+ (NSInteger)maxPixelSizeForCompress:(SYCompressOptions *)compress
                               width:(CGFloat)width
                              height:(CGFloat)height {
    if (width <= 0 || height <= 0) {
        return 0;
    }
    CGFloat longSide = MAX(width, height);

    switch (compress.mode) {
        case SYCompressModeAuto: {
            NSInteger sampleSize = [SYCompressPlan autoSampleSizeForWidth:(NSInteger)width
                                                                   height:(NSInteger)height];
            return sampleSize <= 1 ? 0 : (NSInteger)ceil(longSide / sampleSize);
        }
        case SYCompressModeManual: {
            CGSize target = [SYCompressPlan fitSize:CGSizeMake(width, height)
                                           maxWidth:compress.maxWidth
                                          maxHeight:compress.maxHeight];
            CGFloat targetLong = MAX(target.width, target.height);
            return targetLong >= longSide ? 0 : (NSInteger)targetLong;
        }
        case SYCompressModeNone:
            return 0;
    }
}

/**
 把带方向标记的 UIImage 摆正。

 `UIImage.CGImage` 会丢掉 `imageOrientation`，直接交给 CoreGraphics 编码会让
 竖拍照片躺倒。走原始字节那条路时 ImageIO 会自动处理，这里只兜底内存位图那条。
 */
+ (UIImage *)imageWithUpOrientation:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    }];
}

/// 组装结果字典的公共部分。
+ (NSDictionary *)resultForPath:(NSString *)path
                           data:(NSData *)data
                    originalUri:(nullable NSString *)originalUri
                          width:(CGFloat)width
                         height:(CGFloat)height
                   originalName:(nullable NSString *)originalName
                          asset:(nullable PHAsset *)asset
                  includeBase64:(BOOL)includeBase64 {
    NSString *uri = [NSURL fileURLWithPath:path].absoluteString;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"uri"] = uri;
    if (originalUri.length > 0) {
        result[@"originalUri"] = originalUri;
    }
    result[@"width"] = @(width);
    result[@"height"] = @(height);
    result[@"size"] = @(data.length);
    if (originalName.length > 0) {
        result[@"fileName"] = originalName;
    }
    if (asset.localIdentifier.length > 0) {
        result[@"assetId"] = asset.localIdentifier;
    }
    if (includeBase64) {
        NSString *base64 = [self base64ForData:data];
        if (base64) {
            result[@"base64"] = base64;
        }
    }
    return [result copy];
}

/// 把 data 落盘到缓存目录，返回文件路径。
+ (nullable NSString *)writeData:(NSData *)data
                       extension:(NSString *)extension
                           error:(NSError **)error {
    NSString *path = [[self cacheDirectory]
        stringByAppendingPathComponent:[self uniqueFileNameWithExtension:extension]];
    NSError *writeError = nil;
    // 老实现忽略了 writeToFile 的返回值，写失败也照样返回一个不存在的路径。
    if (![data writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
        if (error) {
            *error = writeError ?: [self errorWithMessage:@"文件写入失败"];
        }
        return nil;
    }
    return path;
}

/// 原始字节的统一入口：相册走 PHAsset，相机走源文件 URL。
+ (nullable NSData *)originalDataForAsset:(nullable PHAsset *)asset
                                sourceURL:(nullable NSURL *)sourceURL {
    if (asset) {
        NSData *data = [self originalDataForAsset:asset];
        if (data.length > 0) {
            return data;
        }
    }
    if (sourceURL.isFileURL) {
        return [NSData dataWithContentsOfURL:sourceURL];
    }
    return nil;
}

+ (nullable NSDictionary *)exportImage:(UIImage *)image
                                 asset:(nullable PHAsset *)asset
                             sourceURL:(nullable NSURL *)sourceURL
                              compress:(SYCompressOptions *)compress
                         includeBase64:(BOOL)includeBase64
                     allowOriginalData:(BOOL)allowOriginalData
                     originalRequested:(BOOL)originalRequested
                          keepOriginal:(BOOL)keepOriginal
                                 error:(NSError **)error {
    NSString *originalName =
        [self originalFileNameForAsset:asset] ?: sourceURL.lastPathComponent;
    NSString *originalExtension = [originalName.pathExtension lowercaseString];
    BOOL isGIF = [originalExtension isEqualToString:@"gif"];

    /*
     以下三种情况必须原样落盘，不能重编码：
       - GIF：转成 JPEG 会把动画拍平成一帧
       - compress.enabled == NO：用户明确要求"不压缩"
       - 用户勾选了"原图"
     早先的实现无差别地一律 JPEG 编码，上述语义全部失效。

     裁剪过的图片除外（allowOriginalData == NO）：原始字节里没有裁剪结果。
     */
    BOOL wantsOriginal =
        allowOriginalData && (originalRequested || isGIF || !compress.enabled);

    if (wantsOriginal) {
        NSData *originalData = [self originalDataForAsset:asset sourceURL:sourceURL];
        if (originalData.length > 0) {
            NSString *extension = originalExtension.length > 0 ? originalExtension : @"jpg";
            NSString *path = [self writeData:originalData extension:extension error:error];
            if (!path) {
                return nil;
            }
            NSString *uri = [NSURL fileURLWithPath:path].absoluteString;

            NSMutableDictionary *result = [NSMutableDictionary dictionary];
            result[@"uri"] = uri;
            // 只有调用方明确要求保留原图时才暴露该可选字段。
            if (keepOriginal) {
                result[@"originalUri"] = uri;
            }
            result[@"width"] = @(asset.pixelWidth > 0 ? asset.pixelWidth
                                                      : image.size.width * image.scale);
            result[@"height"] = @(asset.pixelHeight > 0 ? asset.pixelHeight
                                                        : image.size.height * image.scale);
            result[@"size"] = @(originalData.length);
            if (originalName.length > 0) {
                result[@"fileName"] = originalName;
            }
            if (asset.localIdentifier.length > 0) {
                result[@"assetId"] = asset.localIdentifier;
            }
            if (includeBase64) {
                NSString *base64 = [self base64ForData:originalData];
                if (base64) {
                    result[@"base64"] = base64;
                }
            }
            return [result copy];
        }
        // 取不到原始字节（例如 iCloud 下载失败）则退回重编码，不中断流程。
    }

    if (!image) {
        if (error) {
            *error = [self errorWithMessage:@"图片为空"];
        }
        return nil;
    }

    // 原始字节只取一次：既用于 minSize 判定，也用于后面的 originalUri。
    NSData *originalData = [self originalDataForAsset:asset sourceURL:sourceURL];

    /*
     minSize 兜底（两端一致）：源文件本来就很小时直接原样落盘。
     把一张几十 KB 的图重新编码，结果往往比原图还大。
     */
    /*
     注意 `allowOriginalData` 这个条件：裁剪过的图**绝不能**走这条捷径。

     原来只判文件大小，于是任何小于 100KB 的源图（小截图、头像）都会把
     **未裁剪的原始字节**当作结果写出去，用户的裁剪被静默丢弃，返回的
     uri / width / height / base64 全是原图。
     */
    if (allowOriginalData && originalData.length > 0 &&
        originalData.length < (NSUInteger)compress.minSize * 1024) {
        NSString *extension = originalExtension.length > 0 ? originalExtension : @"jpg";
        NSString *path = [self writeData:originalData extension:extension error:error];
        if (!path) {
            return nil;
        }
        NSString *uri = [NSURL fileURLWithPath:path].absoluteString;
        return [self resultForPath:path
                              data:originalData
                       originalUri:keepOriginal ? uri : nil
                             width:asset.pixelWidth > 0 ? asset.pixelWidth
                                                        : image.size.width * image.scale
                            height:asset.pixelHeight > 0 ? asset.pixelHeight
                                                         : image.size.height * image.scale
                      originalName:originalName
                             asset:asset
                     includeBase64:includeBase64];
    }

    /*
     决定输出 PNG 还是 JPEG。

     判据是**图里到底有没有 alpha**，而不是扩展名或开关。早先写的是
     `isPNG && compress.keepAlpha`，而 keepAlpha 默认为 NO —— 于是一张透明 PNG
     用默认参数选进来，出来是 JPEG、透明区域变黑。那不是"格式变了"，是内容被改了，
     属于静默数据损失。

     现在：有 alpha 就自动保 PNG（用户不必记得开开关），没有 alpha 的 PNG
     （截图之类）仍转 JPEG 以拿到体积收益。keepAlpha 退化为"强制输出 PNG"的逃生舱。
     */
    BOOL hasAlpha = originalData.length > 0
                        ? [SYImageCodec sourceDataHasAlpha:originalData]
                        : [SYImageCodec imageHasAlpha:image.CGImage];
    BOOL writePNG = hasAlpha || compress.keepAlpha;

    /*
     走到这里说明要真正压缩了。降采样是主要手段 —— 调质量的收益远不如降分辨率，
     算法与 Android 的 CompressPlan 逐行对应，保证两端输出像素尺寸一致。
     */
    /*
     计划必须按**将要被编码的那份数据**的真实像素尺寸来算。

     TZImagePickerController 默认 `photoWidth = 828`，交给我们的 UIImage 是缩放过的
     预览图。拿它算计划的话：4032×3024 的照片会被当成 828×621，autoSampleSize 返回 1
     （长边 < 1664）→ maxPixelSize = 0 → 按原图长边输出 4032×3024，降采样等于没做，
     而 Android 输出 2016×1512 —— 直接违反 docs/compress-parity.md 的两端一致契约。
     手动模式更糟：maxWidth: 1000 对 828 宽的图算出"无需缩放"，尺寸上限被静默忽略。

     所以：走原始字节时用 PHAsset 的真实像素尺寸；裁剪过（只能编码内存位图）时，
     UIImage 本身就是最终内容，用它的尺寸才对。
     */
    BOOL willEncodeOriginalBytes = allowOriginalData && originalData.length > 0;
    CGFloat sourceWidth;
    CGFloat sourceHeight;
    if (willEncodeOriginalBytes && asset.pixelWidth > 0 && asset.pixelHeight > 0) {
        sourceWidth = asset.pixelWidth;
        sourceHeight = asset.pixelHeight;
    } else {
        sourceWidth = image.size.width * image.scale;
        sourceHeight = image.size.height * image.scale;
    }

    NSInteger maxPixelSize = [self maxPixelSizeForCompress:compress
                                                     width:sourceWidth
                                                    height:sourceHeight];

    /*
     若拿不到原始字节且用户要求"不压缩"，质量必须是 1.0 ——
     用默认的 0.9 编码等于静默违反了 compress: false 的语义。
     */
    CGFloat quality = compress.enabled ? [compress jpegQuality] : 1.0f;

    CGSize encodedSize = CGSizeZero;
    NSData *data = nil;

    /*
     首选从**原始字节**走 ImageIO：decode-at-size，内存占用远低于先整图解码再缩，
     并且会自动按 EXIF 摆正。裁剪过的图不能走这条 —— 原始字节里没有裁剪结果。
     */
    if (willEncodeOriginalBytes) {
        data = [SYImageCodec encodeSourceData:originalData
                                 maxPixelSize:maxPixelSize
                                      quality:quality
                                    keepAlpha:writePNG
                                   outputSize:&encodedSize];
    }

    // 兜底：裁剪过，或原始字节取不到，只能编码内存中的位图。
    if (data.length == 0) {
        UIImage *upright = [self imageWithUpOrientation:image];
        data = [SYImageCodec encodeImage:upright.CGImage
                            maxPixelSize:maxPixelSize
                                 quality:quality
                               keepAlpha:writePNG
                              outputSize:&encodedSize];
    }

    if (data.length == 0) {
        if (error) {
            *error = [self errorWithMessage:@"图片编码失败"];
        }
        return nil;
    }

    NSString *path = [self writeData:data extension:(writePNG ? @"png" : @"jpg") error:error];
    if (!path) {
        return nil;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:path];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"uri"] = fileURL.absoluteString;
    // 用实际编码出来的尺寸，而不是源尺寸 —— 降采样之后两者不同。
    result[@"width"] = @(encodedSize.width > 0 ? encodedSize.width : sourceWidth);
    result[@"height"] = @(encodedSize.height > 0 ? encodedSize.height : sourceHeight);
    result[@"size"] = @(data.length);

    /*
     originalUri 只在 keepOriginal 时提供。

     它需要额外落盘一份原始字节 —— 每张图一次完整写盘，直接计入用户选完之后的
     等待时间。默认关闭；不开时干脆不给这个字段，也好过给一个指向压缩产物的
     假值（早先的实现就是那样，等于字段在说谎）。
     */
    if (keepOriginal && originalData.length > 0) {
        NSString *extension = originalExtension.length > 0 ? originalExtension : @"jpg";
        NSString *originalPath = [self writeData:originalData extension:extension error:NULL];
        if (originalPath) {
            result[@"originalUri"] = [NSURL fileURLWithPath:originalPath].absoluteString;
        }
    }
    if (originalName.length > 0) {
        result[@"fileName"] = originalName;
    }
    // 供 selectedAssets 回填使用 —— uri 指向的是缓存产物，反查不回相册。
    if (asset.localIdentifier.length > 0) {
        result[@"assetId"] = asset.localIdentifier;
    }
    if (includeBase64) {
        NSString *base64 = [self base64ForData:data];
        if (base64) {
            result[@"base64"] = base64;
        }
    }
    return [result copy];
}

#pragma mark - 视频

+ (nullable NSDictionary *)exportVideoForAsset:(PHAsset *)asset
                                    coverImage:(nullable UIImage *)coverImage
                                     transcode:(BOOL)transcode
                                         error:(NSError **)error {
    if (!asset) {
        if (error) {
            *error = [self errorWithMessage:@"视频资源为空"];
        }
        return nil;
    }

    /*
     默认 passthrough：只复制容器、不重新编码，比完整转码快一个数量级且零画质
     损失。本库本来就不做视频压缩，没有理由把视频整个转一遍 —— 老实现固定用
     HighestQuality，一个 1 分钟的 4K 视频要等几十秒。

     但 TZ 的主导出路径把 outputFileType 写死成了 AVFileTypeMPEG4，某些源格式
     passthrough 进 mp4 容器会失败，所以**失败时自动回退到转码**：常见情况快，
     边缘情况仍然能出结果。
     */
    NSString *path = [self exportVideoPathForAsset:asset
                                        presetName:transcode
                                                       ? AVAssetExportPresetHighestQuality
                                                       : AVAssetExportPresetPassthrough];
    if (!path && !transcode) {
        NSLog(@"[RNSyanImagePicker] passthrough 导出失败，回退到转码");
        path = [self exportVideoPathForAsset:asset
                                  presetName:AVAssetExportPresetHighestQuality];
    }

    if (path.length == 0) {
        if (error) {
            *error = [self errorWithMessage:@"视频导出失败"];
        }
        return nil;
    }

    return [self videoResultForPath:path coverImage:coverImage asset:asset error:error];
}

/// 用指定 preset 同步导出，失败或超时返回 nil。
+ (nullable NSString *)exportVideoPathForAsset:(PHAsset *)asset
                                    presetName:(NSString *)presetName {
    __block NSString *outputPath = nil;
    __block NSString *failureMessage = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    [[TZImageManager manager] getVideoOutputPathWithAsset:asset
        presetName:presetName
        success:^(NSString *path) {
            outputPath = path;
            dispatch_semaphore_signal(semaphore);
        }
        failure:^(NSString *errorMessage, NSError *innerError) {
            // 老实现这个块**是空的** —— 于是导出一失败，promise 和 HUD 就一起卡死。
            failureMessage = errorMessage ?: innerError.localizedDescription ?: @"视频导出失败";
            dispatch_semaphore_signal(semaphore);
        }];

    dispatch_time_t deadline =
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSYVideoExportTimeout * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(semaphore, deadline) != 0) {
        NSLog(@"[RNSyanImagePicker] 视频导出超时（preset=%@）", presetName);
        return nil;
    }
    if (outputPath.length == 0 && failureMessage.length > 0) {
        NSLog(@"[RNSyanImagePicker] 视频导出失败（preset=%@）: %@", presetName, failureMessage);
    }
    return outputPath.length > 0 ? outputPath : nil;
}

+ (nullable NSDictionary *)exportVideoAtURL:(NSURL *)url error:(NSError **)error {
    if (!url.isFileURL) {
        if (error) {
            *error = [self errorWithMessage:@"录制结果不是本地文件"];
        }
        return nil;
    }
    return [self videoResultForPath:url.path coverImage:nil asset:nil error:error];
}

/**
 把视频挪进受管理的缓存目录。

 TZImagePickerController 把导出结果写在 `NSTemporaryDirectory()/video-*.mp4`，
 相机录制的结果也在系统临时目录 —— 两者都不在本库的缓存子目录下，`clearCache()`
 清不到，视频会一直堆积。这里统一搬过去。

 @return 新路径；搬运失败时返回原路径（功能优先，不因为清理问题中断流程）。
 */
+ (NSString *)moveIntoCacheDirectory:(NSString *)path {
    NSString *cacheDir = [self cacheDirectory];
    if ([path hasPrefix:cacheDir]) {
        return path; // 已经在受管理目录里了
    }

    NSString *extension = path.pathExtension.length > 0 ? path.pathExtension : @"mp4";
    NSString *target =
        [cacheDir stringByAppendingPathComponent:[self uniqueFileNameWithExtension:extension]];

    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *moveError = nil;
    if ([manager moveItemAtPath:path toPath:target error:&moveError]) {
        return target;
    }
    // 跨卷等情况下 move 会失败，退回复制。
    if ([manager copyItemAtPath:path toPath:target error:NULL]) {
        return target;
    }
    NSLog(@"[RNSyanImagePicker] 视频移入缓存目录失败: %@", moveError);
    return path;
}

+ (nullable NSDictionary *)videoResultForPath:(NSString *)originalPath
                                   coverImage:(nullable UIImage *)coverImage
                                        asset:(nullable PHAsset *)asset
                                        error:(NSError **)error {
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:originalPath]) {
        if (error) {
            *error = [self errorWithMessage:@"视频文件不存在"];
        }
        return nil;
    }

    NSString *path = [self moveIntoCacheDirectory:originalPath];

    AVURLAsset *urlAsset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:path]];
    CGSize dimensions = CGSizeZero;
    AVAssetTrack *track = [[urlAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (track) {
        // 应用 preferredTransform，否则竖屏视频拿到的是转置过的宽高。
        dimensions = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
        dimensions = CGSizeMake(fabs(dimensions.width), fabs(dimensions.height));
    }

    UIImage *cover = coverImage ?: [self generateCoverForAsset:urlAsset];
    NSString *coverUri = @"";
    if (cover) {
        NSData *coverData = UIImageJPEGRepresentation(cover, 0.8f);
        NSString *coverPath = [[self cacheDirectory]
            stringByAppendingPathComponent:[self uniqueFileNameWithExtension:@"jpg"]];
        if ([coverData writeToFile:coverPath options:NSDataWritingAtomic error:NULL]) {
            coverUri = [NSURL fileURLWithPath:coverPath].absoluteString;
        }
    }

    NSNumber *fileSize = [manager attributesOfItemAtPath:path error:NULL][NSFileSize];

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"uri"] = [NSURL fileURLWithPath:path].absoluteString;
    result[@"width"] = @(dimensions.width);
    result[@"height"] = @(dimensions.height);
    result[@"size"] = fileSize ?: @0;
    result[@"duration"] = @(CMTimeGetSeconds(urlAsset.duration) * 1000.0);
    // 按真实扩展名推导。相机录制出来的通常是 .mov，早先固定上报 video/mp4，
    // 会让容器格式与 MIME 元数据对不上，影响上传和服务端解析。
    result[@"mime"] = [self mimeTypeForPath:path];
    result[@"coverUri"] = coverUri;

    NSString *originalName = [self originalFileNameForAsset:asset] ?: path.lastPathComponent;
    if (originalName.length > 0) {
        result[@"fileName"] = originalName;
    }
    if (asset.localIdentifier.length > 0) {
        result[@"assetId"] = asset.localIdentifier;
    }
    return [result copy];
}

+ (NSString *)mimeTypeForPath:(NSString *)path {
    NSString *extension = [path.pathExtension lowercaseString];
    NSDictionary<NSString *, NSString *> *table = @{
        @"mov" : @"video/quicktime",
        @"qt" : @"video/quicktime",
        @"mp4" : @"video/mp4",
        @"m4v" : @"video/x-m4v",
        @"3gp" : @"video/3gpp",
        @"avi" : @"video/x-msvideo",
        @"mkv" : @"video/x-matroska",
    };
    return table[extension] ?: @"video/mp4";
}

+ (nullable UIImage *)generateCoverForAsset:(AVAsset *)asset {
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    CGImageRef cgImage =
        [generator copyCGImageAtTime:CMTimeMake(0, 1) actualTime:NULL error:NULL];
    if (!cgImage) {
        return nil;
    }
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}

@end
