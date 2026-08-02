#import "SYPickerOptions.h"

/* -------------------------------------------------------------------------- */
/* 安全取值                                                                    */
/* -------------------------------------------------------------------------- */

static BOOL SYBool(NSDictionary *dict, NSString *key, BOOL fallback) {
    id value = [dict isKindOfClass:[NSDictionary class]] ? dict[key] : nil;
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : fallback;
}

static NSInteger SYInteger(NSDictionary *dict, NSString *key, NSInteger fallback) {
    id value = [dict isKindOfClass:[NSDictionary class]] ? dict[key] : nil;
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : fallback;
}

static NSDictionary *_Nullable SYDict(NSDictionary *dict, NSString *key) {
    id value = [dict isKindOfClass:[NSDictionary class]] ? dict[key] : nil;
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray<NSString *> *SYStringArray(NSDictionary *dict, NSString *key) {
    id value = [dict isKindOfClass:[NSDictionary class]] ? dict[key] : nil;
    if (![value isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (id item in (NSArray *)value) {
        if ([item isKindOfClass:[NSString class]] && [(NSString *)item length] > 0) {
            [result addObject:item];
        }
    }
    return [result copy];
}

/* -------------------------------------------------------------------------- */

@implementation SYCropOptions

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SYCropOptions *options = [SYCropOptions new];
    options.enabled = SYBool(dict, @"enabled", NO);
    options.width = SYInteger(dict, @"width", 0);
    options.height = SYInteger(dict, @"height", 0);
    options.circle = SYBool(dict, @"circle", NO);
    options.showFrame = SYBool(dict, @"showFrame", YES);
    options.showGrid = SYBool(dict, @"showGrid", NO);
    return options;
}

@end

@implementation SYCompressOptions

+ (SYCompressMode)modeFromString:(NSString *)value {
    if ([value isEqualToString:@"none"]) {
        return SYCompressModeNone;
    }
    if ([value isEqualToString:@"manual"]) {
        return SYCompressModeManual;
    }
    return SYCompressModeAuto; // 缺省即自动，与 TS 侧一致
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SYCompressOptions *options = [SYCompressOptions new];
    id rawMode = [dict isKindOfClass:[NSDictionary class]] ? dict[@"mode"] : nil;
    options.mode = [self modeFromString:[rawMode isKindOfClass:[NSString class]] ? rawMode : nil];
    options.quality = MIN(MAX(SYInteger(dict, @"quality", 90), 1), 100);
    options.maxWidth = MAX(SYInteger(dict, @"maxWidth", 0), 0);
    options.maxHeight = MAX(SYInteger(dict, @"maxHeight", 0), 0);
    options.minSize = MAX(SYInteger(dict, @"minSize", 100), 0);
    options.keepAlpha = SYBool(dict, @"keepAlpha", NO);
    return options;
}

- (BOOL)enabled {
    return self.mode != SYCompressModeNone;
}

- (CGFloat)jpegQuality {
    // 显式用浮点除法。老实现把 quality 解析成 NSInteger 再做 `quality/100`，
    // 只是碰巧因为形参是 CGFloat 才没退化成整数除法 —— 那是运气，不是设计。
    return (CGFloat)self.quality / 100.0f;
}

@end

@implementation SYImageOptions

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SYImageOptions *options = [SYImageOptions new];
    options.maxCount = MAX(SYInteger(dict, @"maxCount", 6), 1);
    options.minCount = MAX(SYInteger(dict, @"minCount", 0), 0);
    options.maxFileSize = MAX(SYInteger(dict, @"maxFileSize", 0), 0);
    options.minFileSize = MAX(SYInteger(dict, @"minFileSize", 0), 0);
    options.showCameraButton = SYBool(dict, @"showCameraButton", YES);
    options.allowGif = SYBool(dict, @"allowGif", NO);
    options.allowOriginal = SYBool(dict, @"allowOriginal", NO);
    options.includeBase64 = SYBool(dict, @"includeBase64", NO);
    options.keepOriginal = SYBool(dict, @"keepOriginal", NO);
    options.showLoading = SYBool(dict, @"showLoading", YES);
    options.sortAscending = SYBool(dict, @"sortAscending", YES);
    options.showSelectionIndex = SYBool(dict, @"showSelectionIndex", NO);
    options.wechatStyle = SYBool(dict, @"wechatStyle", NO);
    options.selectedUris = SYStringArray(dict, @"selectedUris");
    options.crop = [SYCropOptions fromDictionary:SYDict(dict, @"crop")];
    options.compress = [SYCompressOptions fromDictionary:SYDict(dict, @"compress")];
    return options;
}

@end

@implementation SYVideoOptions

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SYVideoOptions *options = [SYVideoOptions new];
    options.transcode = SYBool(dict, @"transcode", NO);
    options.showLoading = SYBool(dict, @"showLoading", YES);
    options.maxCount = MAX(SYInteger(dict, @"maxCount", 1), 1);
    options.minCount = MAX(SYInteger(dict, @"minCount", 0), 0);
    options.maxFileSize = MAX(SYInteger(dict, @"maxFileSize", 0), 0);
    options.minFileSize = MAX(SYInteger(dict, @"minFileSize", 0), 0);
    options.showCameraButton = SYBool(dict, @"showCameraButton", YES);
    options.sortAscending = SYBool(dict, @"sortAscending", YES);
    options.selectedUris = SYStringArray(dict, @"selectedUris");
    options.maxDuration = MAX(SYInteger(dict, @"maxDuration", 180), 0);
    options.minDuration = MAX(SYInteger(dict, @"minDuration", 0), 0);
    return options;
}

@end

@implementation SYCaptureImageOptions

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SYCaptureImageOptions *options = [SYCaptureImageOptions new];
    options.includeBase64 = SYBool(dict, @"includeBase64", NO);
    options.keepOriginal = SYBool(dict, @"keepOriginal", NO);
    options.crop = [SYCropOptions fromDictionary:SYDict(dict, @"crop")];
    options.compress = [SYCompressOptions fromDictionary:SYDict(dict, @"compress")];
    return options;
}

@end

@implementation SYCaptureVideoOptions

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SYCaptureVideoOptions *options = [SYCaptureVideoOptions new];
    options.recordDuration = MAX(SYInteger(dict, @"recordDuration", 60), 1);
    return options;
}

@end
