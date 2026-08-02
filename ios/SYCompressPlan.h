#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/**
 压缩计划的计算 —— **纯函数，不碰任何图像 API**。

 Android 侧有一份逐行对应的实现（`CompressPlan.kt`）。两边必须保持一致：
 这是"自动模式两端输出像素尺寸完全相同"这条契约的落点，改动时请同步修改并
 更新两侧的对拍用例。
 */
@interface SYCompressPlan : NSObject

/**
 自动模式的降采样倍率，与微信/Luban 同源的启发式。

 返回值**保证是 2 的幂** —— Android 的 BitmapFactory 本来就会把 inSampleSize
 向下取整到 2 的幂，这里显式对齐，否则两端算出的目标尺寸对不上。
 */
+ (NSInteger)autoSampleSizeForWidth:(NSInteger)width height:(NSInteger)height;

/// 向下取整到最近的 2 的幂，最小为 1。
+ (NSInteger)normalizeSampleSize:(NSInteger)value;

/**
 手动模式：把尺寸等比缩放进 maxWidth × maxHeight 的边界框。
 任一上限传 0 表示该方向不限制；永远不放大。
 */
+ (CGSize)fitSize:(CGSize)size
         maxWidth:(NSInteger)maxWidth
        maxHeight:(NSInteger)maxHeight;

@end

NS_ASSUME_NONNULL_END
