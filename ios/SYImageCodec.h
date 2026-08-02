#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 图片降采样与编码。

 **刻意只依赖 ImageIO / CoreGraphics，不碰 UIKit。** 两个理由：

 1. `CGImageSourceCreateThumbnailAtIndex` 是 decode-at-size —— 不必先把整张
    12MP 图解码进内存再缩，内存占用比 UIKit 那条路低一个量级；顺带还会按 EXIF
    自动摆正方向，省掉一整类"竖拍照片压完躺倒"的 bug。
 2. 这两个框架在 macOS 上同样存在，因此本类可以用一个普通的 clang 命令行程序
    直接测试 —— 不需要模拟器、不需要 Xcode test target。测试见 `ios/tests/`。
 */
@interface SYImageCodec : NSObject

/**
 从原始图片数据降采样并编码。

 @param maxPixelSize 目标**长边**像素数；传 0 表示不缩放（仍会应用 EXIF 方向）。
 @param quality      0–1，仅对 JPEG 有效。
 @param keepAlpha    YES 输出 PNG（保留透明通道），NO 输出 JPEG。
 @param outputSize   非空时回填实际输出的像素尺寸。
 @return 编码后的数据；失败返回 nil。
 */
+ (nullable NSData *)encodeSourceData:(NSData *)source
                         maxPixelSize:(NSInteger)maxPixelSize
                              quality:(CGFloat)quality
                            keepAlpha:(BOOL)keepAlpha
                           outputSize:(nullable CGSize *)outputSize;

/**
 从已解码的位图编码。

 裁剪之后走这条 —— 此时原始字节里并没有裁剪结果，只能拿内存中的图去编码。
 */
+ (nullable NSData *)encodeImage:(CGImageRef)image
                    maxPixelSize:(NSInteger)maxPixelSize
                         quality:(CGFloat)quality
                       keepAlpha:(BOOL)keepAlpha
                      outputSize:(nullable CGSize *)outputSize;

/** 读取图片数据的像素尺寸（已按 EXIF 方向换算），不解码整图。失败返回 CGSizeZero。 */
+ (CGSize)pixelSizeOfSourceData:(NSData *)source;

/** 原始数据里是否含透明通道。读元数据即可，不解码整图。 */
+ (BOOL)sourceDataHasAlpha:(NSData *)source;

/** 位图是否含透明通道。 */
+ (BOOL)imageHasAlpha:(CGImageRef)image;

@end

NS_ASSUME_NONNULL_END
