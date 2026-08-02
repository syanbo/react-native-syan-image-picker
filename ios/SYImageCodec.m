#import "SYImageCodec.h"

#import <ImageIO/ImageIO.h>

@implementation SYImageCodec

#pragma mark - 尺寸

+ (CGSize)pixelSizeOfSourceData:(NSData *)source {
    if (source.length == 0) {
        return CGSizeZero;
    }
    CGImageSourceRef imageSource =
        CGImageSourceCreateWithData((__bridge CFDataRef)source, NULL);
    if (!imageSource) {
        return CGSizeZero;
    }

    CGSize size = CGSizeZero;
    NSDictionary *properties = (__bridge_transfer NSDictionary *)
        CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
    if (properties) {
        CGFloat width = [properties[(id)kCGImagePropertyPixelWidth] doubleValue];
        CGFloat height = [properties[(id)kCGImagePropertyPixelHeight] doubleValue];

        // 属性里的宽高是**未应用 EXIF 方向**的，方向为 5–8 时需要交换。
        NSInteger orientation =
            [properties[(id)kCGImagePropertyOrientation] integerValue];
        if (orientation >= 5 && orientation <= 8) {
            size = CGSizeMake(height, width);
        } else {
            size = CGSizeMake(width, height);
        }
    }

    CFRelease(imageSource);
    return size;
}

+ (BOOL)sourceDataHasAlpha:(NSData *)source {
    if (source.length == 0) {
        return NO;
    }
    CGImageSourceRef imageSource =
        CGImageSourceCreateWithData((__bridge CFDataRef)source, NULL);
    if (!imageSource) {
        return NO;
    }
    NSDictionary *properties = (__bridge_transfer NSDictionary *)
        CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);
    return [properties[(id)kCGImagePropertyHasAlpha] boolValue];
}

+ (BOOL)imageHasAlpha:(CGImageRef)image {
    if (!image) {
        return NO;
    }
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image);
    return alpha != kCGImageAlphaNone && alpha != kCGImageAlphaNoneSkipFirst &&
           alpha != kCGImageAlphaNoneSkipLast;
}

#pragma mark - 编码

/// 统一的写出逻辑，两条路径共用。
+ (nullable NSData *)writeImage:(CGImageRef)image
                        quality:(CGFloat)quality
                      keepAlpha:(BOOL)keepAlpha {
    if (!image) {
        return nil;
    }

    NSMutableData *output = [NSMutableData data];
    CFStringRef type = keepAlpha ? CFSTR("public.png") : CFSTR("public.jpeg");
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)output, type, 1, NULL);
    if (!destination) {
        return nil;
    }

    NSDictionary *options = @{
        (id)kCGImageDestinationLossyCompressionQuality : @(MIN(MAX(quality, 0.0), 1.0))
    };
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    BOOL ok = CGImageDestinationFinalize(destination);
    CFRelease(destination);

    return (ok && output.length > 0) ? output : nil;
}

+ (nullable NSData *)encodeSourceData:(NSData *)source
                         maxPixelSize:(NSInteger)maxPixelSize
                              quality:(CGFloat)quality
                            keepAlpha:(BOOL)keepAlpha
                           outputSize:(CGSize *)outputSize {
    if (source.length == 0) {
        return nil;
    }
    CGImageSourceRef imageSource =
        CGImageSourceCreateWithData((__bridge CFDataRef)source, NULL);
    if (!imageSource) {
        return nil;
    }

    // maxPixelSize 为 0 时用源图长边，这样仍会走 thumbnail 路径 ——
    // 目的是让 kCGImageSourceCreateThumbnailWithTransform 把 EXIF 方向应用上。
    NSInteger limit = maxPixelSize;
    if (limit <= 0) {
        CGSize pixelSize = [self pixelSizeOfSourceData:source];
        limit = (NSInteger)MAX(pixelSize.width, pixelSize.height);
        if (limit <= 0) {
            CFRelease(imageSource);
            return nil;
        }
    }

    NSDictionary *thumbOptions = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize : @(limit),
        // 关键：自动按 EXIF 摆正，Android 侧则要手写旋转矩阵。
        (id)kCGImageSourceCreateThumbnailWithTransform : @YES,
    };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(
        imageSource, 0, (__bridge CFDictionaryRef)thumbOptions);
    CFRelease(imageSource);

    if (!image) {
        return nil;
    }

    if (outputSize) {
        *outputSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    }
    NSData *result = [self writeImage:image quality:quality keepAlpha:keepAlpha];
    CGImageRelease(image);
    return result;
}

+ (nullable NSData *)encodeImage:(CGImageRef)image
                    maxPixelSize:(NSInteger)maxPixelSize
                         quality:(CGFloat)quality
                       keepAlpha:(BOOL)keepAlpha
                      outputSize:(CGSize *)outputSize {
    if (!image) {
        return nil;
    }

    size_t srcWidth = CGImageGetWidth(image);
    size_t srcHeight = CGImageGetHeight(image);
    if (srcWidth == 0 || srcHeight == 0) {
        return nil;
    }

    CGImageRef target = (CGImageRef)CFRetain(image);

    NSInteger longSide = (NSInteger)MAX(srcWidth, srcHeight);
    if (maxPixelSize > 0 && longSide > maxPixelSize) {
        double scale = (double)maxPixelSize / longSide;
        size_t width = MAX((size_t)1, (size_t)(srcWidth * scale));
        size_t height = MAX((size_t)1, (size_t)(srcHeight * scale));

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = keepAlpha
            ? (CGBitmapInfo)kCGImageAlphaPremultipliedLast
            : (CGBitmapInfo)kCGImageAlphaNoneSkipLast;
        CGContextRef context = CGBitmapContextCreate(
            NULL, width, height, 8, 0, colorSpace, bitmapInfo);
        CGColorSpaceRelease(colorSpace);

        if (context) {
            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
            CGImageRef scaled = CGBitmapContextCreateImage(context);
            CGContextRelease(context);
            if (scaled) {
                CFRelease(target);
                target = scaled;
            }
        }
    }

    if (outputSize) {
        *outputSize = CGSizeMake(CGImageGetWidth(target), CGImageGetHeight(target));
    }
    NSData *result = [self writeImage:target quality:quality keepAlpha:keepAlpha];
    CFRelease(target);
    return result;
}

@end
