#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "SYPickerOptions.h"

NS_ASSUME_NONNULL_BEGIN

/**
 把选中的资源落盘成 RN 可直接使用的文件，并生成结果字典。

 **本类的所有方法都会阻塞，必须在后台队列调用。** 老实现把 methodQueue 设成主队列，
 于是 JPEG 编码和 base64 全堵在 UI 线程上。
 */
@interface SYAssetExporter : NSObject

/**
 导出一张图片。

 @param sourceURL 相机拍摄产生的源文件（`UIImagePickerControllerImageURL`）。
        相机路径没有 PHAsset，只能靠它拿到未经重编码的原始字节。
 @param allowOriginalData 是否**允许**直接落盘原始字节。裁剪过的图片必须传 NO ——
        原始字节里没有裁剪结果。
 @param originalRequested 用户是否勾选了"原图"。
        另有两种情况即使本参数为 NO 也会走原始字节（前提是 allowOriginalData 为 YES）：
        资源是 GIF（重编码会把动画拍平），或 `compress.enabled` 为 NO
        （既然要求"不压缩"，再转成 JPEG 就自相矛盾了）。
 @param keepOriginal 是否额外落盘一份压缩前的原图，供结果里的 `originalUri` 使用。
        默认关闭 —— 每张图多一次完整写盘会直接计入用户的等待时间。
 @param error 失败时回填，调用方据此 reject EXPORT_FAILED。
 @return 结果字典；失败返回 nil。
 */
+ (nullable NSDictionary *)exportImage:(UIImage *)image
                                 asset:(nullable PHAsset *)asset
                             sourceURL:(nullable NSURL *)sourceURL
                              compress:(SYCompressOptions *)compress
                         includeBase64:(BOOL)includeBase64
                     allowOriginalData:(BOOL)allowOriginalData
                     originalRequested:(BOOL)originalRequested
                          keepOriginal:(BOOL)keepOriginal
                                 error:(NSError **)error;

/**
 导出一个视频（含封面图）。

 内部用信号量把 TZImageManager 的异步导出转成同步，**并带超时**：导出失败或
 迟迟不回调时会返回错误，而不是让 promise 永远挂着 —— 老实现那个空的 failure
 块正是全库最严重的 bug。
 */
+ (nullable NSDictionary *)exportVideoForAsset:(PHAsset *)asset
                                    coverImage:(nullable UIImage *)coverImage
                                     transcode:(BOOL)transcode
                                         error:(NSError **)error;

/// 由已录制好的本地文件生成视频结果（相机录像路径）。
+ (nullable NSDictionary *)exportVideoAtURL:(NSURL *)url error:(NSError **)error;

/**
 取相册资源的**源文件**大小，单位字节；取不到返回 -1。

 走 `requestContentEditingInputWithOptions` 拿到原始文件 URL 后 stat —— 是公开
 API，且**不会把图片读进内存**。iOS 没有廉价的公开方式直接读 PHAsset 的文件大小
 （`PHAssetResource` 不暴露 `fileSize`，只有私有 KVC 能拿，那有 App Review 风险）。

 会阻塞，必须在后台队列调用。
 */
+ (long long)sourceFileSizeForAsset:(nullable PHAsset *)asset;

/// 缓存目录，本库所有产物都写在这里。
+ (NSString *)cacheDirectory;

+ (void)clearCache;

@end

NS_ASSUME_NONNULL_END
