/*
 * 编解码正确性测试。
 *
 * 这里测的才是真正容易出错的部分：降采样后的实际尺寸、EXIF 方向、透明通道、
 * 质量对体积的影响。算法那二十行算术反而是最安全的。
 *
 * SYImageCodec 只依赖 ImageIO / CoreGraphics —— 这两个框架在 macOS 上同样存在，
 * 所以本测试是个普通的命令行程序，秒级完成，不需要模拟器。
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#import "SYImageCodec.h"

static int gFailures = 0;

static void expect(BOOL condition, NSString *what) {
    if (!condition) {
        fprintf(stderr, "  ✗ %s\n", what.UTF8String);
        gFailures++;
    }
}

static void expectEqual(NSInteger actual, NSInteger expected, NSString *what) {
    if (actual != expected) {
        fprintf(stderr, "  ✗ %s: 期望 %ld，实际 %ld\n",
                what.UTF8String, (long)expected, (long)actual);
        gFailures++;
    }
}

/// 造一张纯色位图。
static CGImageRef CreateTestImage(size_t width, size_t height, BOOL withAlpha) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo info = withAlpha ? (CGBitmapInfo)kCGImageAlphaPremultipliedLast
                                  : (CGBitmapInfo)kCGImageAlphaNoneSkipLast;
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 0, space, info);
    CGColorSpaceRelease(space);
    if (!ctx) return NULL;

    // 画点内容，避免纯色被编码器压到接近 0 字节而让体积断言失去意义。
    for (size_t i = 0; i < 40; i++) {
        CGContextSetRGBFillColor(ctx, (i % 7) / 7.0, (i % 5) / 5.0, (i % 3) / 3.0,
                                 withAlpha ? 0.5 : 1.0);
        CGContextFillRect(ctx, CGRectMake(i * (width / 40.0), 0, width / 40.0, height));
    }
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}

/// 把位图编码成 JPEG，可选带 EXIF 方向。
static NSData *MakeJPEG(CGImageRef image, NSInteger orientation) {
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dst =
        CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.jpeg"), 1, NULL);
    NSMutableDictionary *props =
        [@{(id)kCGImageDestinationLossyCompressionQuality : @0.9} mutableCopy];
    if (orientation > 0) {
        props[(id)kCGImagePropertyOrientation] = @(orientation);
    }
    CGImageDestinationAddImage(dst, image, (__bridge CFDictionaryRef)props);
    CGImageDestinationFinalize(dst);
    CFRelease(dst);
    return data;
}

static BOOL DataHasAlpha(NSData *data) {
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!src) return NO;
    CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
    CFRelease(src);
    if (!img) return NO;
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(img);
    CGImageRelease(img);
    return alpha != kCGImageAlphaNone && alpha != kCGImageAlphaNoneSkipLast &&
           alpha != kCGImageAlphaNoneSkipFirst;
}

int main(void) {
    @autoreleasepool {
        printf("编解码正确性\n");

        /* --- 1. 降采样到指定长边 --- */
        CGImageRef big = CreateTestImage(4032, 3024, NO);
        NSData *bigJPEG = MakeJPEG(big, 0);

        CGSize out = CGSizeZero;
        NSData *scaled = [SYImageCodec encodeSourceData:bigJPEG
                                           maxPixelSize:2016
                                                quality:0.6
                                              keepAlpha:NO
                                             outputSize:&out];
        expect(scaled.length > 0, @"降采样应产出数据");
        expectEqual((NSInteger)out.width, 2016, @"降采样宽");
        expectEqual((NSInteger)out.height, 1512, @"降采样高");
        expect(scaled.length < bigJPEG.length, @"降采样后体积应更小");

        /* --- 2. maxPixelSize 为 0 时不缩放 --- */
        CGSize noScale = CGSizeZero;
        NSData *full = [SYImageCodec encodeSourceData:bigJPEG
                                         maxPixelSize:0
                                              quality:0.9
                                            keepAlpha:NO
                                           outputSize:&noScale];
        expect(full.length > 0, @"不缩放应产出数据");
        expectEqual((NSInteger)noScale.width, 4032, @"不缩放时宽度不变");

        /* --- 3. 质量影响体积 --- */
        NSData *low = [SYImageCodec encodeSourceData:bigJPEG maxPixelSize:1000
                                             quality:0.1 keepAlpha:NO outputSize:NULL];
        NSData *high = [SYImageCodec encodeSourceData:bigJPEG maxPixelSize:1000
                                              quality:0.95 keepAlpha:NO outputSize:NULL];
        expect(low.length < high.length, @"低质量体积应小于高质量");

        /* --- 4. EXIF 方向：横图标记为 6（旋转 90°）--- */
        NSData *rotated = MakeJPEG(big, 6);
        CGSize reported = [SYImageCodec pixelSizeOfSourceData:rotated];
        expectEqual((NSInteger)reported.width, 3024, @"EXIF 6 时上报宽高应交换");
        expectEqual((NSInteger)reported.height, 4032, @"EXIF 6 时上报宽高应交换");

        CGSize uprightSize = CGSizeZero;
        NSData *upright = [SYImageCodec encodeSourceData:rotated
                                            maxPixelSize:0
                                                 quality:0.9
                                               keepAlpha:NO
                                              outputSize:&uprightSize];
        expect(upright.length > 0, @"带方向的图应能编码");
        // 输出必须是**已摆正**的，否则竖拍照片在 RN 里会躺倒。
        expectEqual((NSInteger)uprightSize.width, 3024, @"EXIF 应被应用（宽）");
        expectEqual((NSInteger)uprightSize.height, 4032, @"EXIF 应被应用（高）");

        /* --- 5. keepAlpha 输出 PNG 且保留透明通道 --- */
        CGImageRef alphaImage = CreateTestImage(400, 300, YES);
        NSData *png = [SYImageCodec encodeImage:alphaImage
                                   maxPixelSize:0
                                        quality:1.0
                                      keepAlpha:YES
                                     outputSize:NULL];
        expect(png.length > 0, @"PNG 应产出数据");
        expect(DataHasAlpha(png), @"keepAlpha 时应保留透明通道");

        NSData *jpg = [SYImageCodec encodeImage:alphaImage
                                   maxPixelSize:0
                                        quality:0.9
                                      keepAlpha:NO
                                     outputSize:NULL];
        // 注意：codec 层就是"叫它做什么就做什么"，这里验证的是它忠实执行。
        // **是否该丢 alpha 是上层策略** —— SYAssetExporter 现在按图片实际是否
        // 含 alpha 自动决定，不会再拿默认参数把透明 PNG 编成 JPEG。
        expect(!DataHasAlpha(jpg), @"keepAlpha 为 NO 时 codec 应如实输出 JPEG");

        /* --- 8. alpha 检测：上层策略依赖它 --- */
        CGImageRef opaque = CreateTestImage(200, 200, NO);
        expect([SYImageCodec imageHasAlpha:alphaImage], @"含 alpha 的位图应被识别");
        expect(![SYImageCodec imageHasAlpha:opaque], @"不含 alpha 的位图不应误判");

        NSData *opaqueJPEG = MakeJPEG(opaque, 0);
        expect(![SYImageCodec sourceDataHasAlpha:opaqueJPEG], @"JPEG 永远没有 alpha");

        NSData *alphaPNG = [SYImageCodec encodeImage:alphaImage maxPixelSize:0
                                             quality:1.0 keepAlpha:YES outputSize:NULL];
        expect([SYImageCodec sourceDataHasAlpha:alphaPNG], @"透明 PNG 应被识别出 alpha");
        CGImageRelease(opaque);

        /* --- 6. encodeImage 的缩放与不放大 --- */
        CGSize imgOut = CGSizeZero;
        [SYImageCodec encodeImage:big maxPixelSize:1008 quality:0.8
                        keepAlpha:NO outputSize:&imgOut];
        expectEqual((NSInteger)imgOut.width, 1008, @"encodeImage 缩放宽");
        expectEqual((NSInteger)imgOut.height, 756, @"encodeImage 等比高");

        [SYImageCodec encodeImage:alphaImage maxPixelSize:9999 quality:0.8
                        keepAlpha:NO outputSize:&imgOut];
        expectEqual((NSInteger)imgOut.width, 400, @"encodeImage 永不放大");

        /* --- 7. 坏输入不崩 --- */
        expect([SYImageCodec encodeSourceData:[NSData data] maxPixelSize:100
                                      quality:0.8 keepAlpha:NO outputSize:NULL] == nil,
               @"空数据应返回 nil");
        NSData *garbage = [@"not an image" dataUsingEncoding:NSUTF8StringEncoding];
        expect([SYImageCodec encodeSourceData:garbage maxPixelSize:100
                                      quality:0.8 keepAlpha:NO outputSize:NULL] == nil,
               @"非图片数据应返回 nil");
        expect(CGSizeEqualToSize([SYImageCodec pixelSizeOfSourceData:garbage], CGSizeZero),
               @"非图片数据的尺寸应为 zero");

        CGImageRelease(big);
        CGImageRelease(alphaImage);

        if (gFailures == 0) {
            printf("✓ 全部通过\n");
            return 0;
        }
        fprintf(stderr, "✗ %d 处失败\n", gFailures);
        return 1;
    }
}
