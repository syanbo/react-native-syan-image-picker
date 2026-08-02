#import "SYCompressPlan.h"

/* 自适应算法的常量表，与微信/Luban 同源。改这些数字会直接改变输出尺寸。
   Android 侧 CompressPlan.kt 有同名常量，必须同步。 */
static const double kSYRatio9To16 = 0.5625;
static const double kSYRatio1To2 = 0.5;
static const NSInteger kSYLongSideSmall = 1664;
static const NSInteger kSYLongSideMedium = 4990;
static const NSInteger kSYLongSideLarge = 10240;
static const NSInteger kSYBaseLongSide = 1280;

@implementation SYCompressPlan

+ (NSInteger)autoSampleSizeForWidth:(NSInteger)width height:(NSInteger)height {
    if (width <= 0 || height <= 0) {
        return 1;
    }

    // 先偶数化 —— 原算法如此，奇数边会让后续整除产生偏差。
    NSInteger w = (width % 2 == 1) ? width + 1 : width;
    NSInteger h = (height % 2 == 1) ? height + 1 : height;

    NSInteger longSide = MAX(w, h);
    NSInteger shortSide = MIN(w, h);
    double ratio = (double)shortSide / (double)longSide;

    NSInteger raw;
    if (ratio > kSYRatio9To16) {
        if (longSide < kSYLongSideSmall) {
            raw = 1;
        } else if (longSide < kSYLongSideMedium) {
            raw = 2;
        } else if (longSide < kSYLongSideLarge) {
            raw = 4;
        } else {
            raw = longSide / kSYBaseLongSide;
        }
    } else if (ratio > kSYRatio1To2) {
        raw = longSide / kSYBaseLongSide;
    } else {
        raw = (NSInteger)ceil((double)longSide / (kSYBaseLongSide / ratio));
    }

    return [self normalizeSampleSize:raw];
}

+ (NSInteger)normalizeSampleSize:(NSInteger)value {
    if (value <= 1) {
        return 1;
    }
    NSInteger result = 1;
    while (result * 2 <= value) {
        result *= 2;
    }
    return result;
}

+ (CGSize)fitSize:(CGSize)size
         maxWidth:(NSInteger)maxWidth
        maxHeight:(NSInteger)maxHeight {
    if (size.width <= 0 || size.height <= 0) {
        return size;
    }

    double scale = 1.0;
    if (maxWidth > 0) {
        scale = MIN(scale, (double)maxWidth / size.width);
    }
    if (maxHeight > 0) {
        scale = MIN(scale, (double)maxHeight / size.height);
    }

    if (scale >= 1.0) {
        return size; // 永远不放大
    }

    return CGSizeMake(MAX(1, (NSInteger)(size.width * scale)),
                      MAX(1, (NSInteger)(size.height * scale)));
}

@end
