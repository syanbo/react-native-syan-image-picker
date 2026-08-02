#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 跨桥选项的强类型表示。

 JS 层保证传过来的字典是补全过的，但这里依然对每个键做类型校验后再取值 ——
 老实现直接把 NSDictionary 存成模块属性、在各处随手取值，于是视频路径读到的
 是上一次调用残留的选项。用不可变的值对象可以从根上避免这类串味。
 */

@interface SYCropOptions : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) BOOL circle;
@property (nonatomic, assign) BOOL showFrame;
@property (nonatomic, assign) BOOL showGrid;
+ (instancetype)fromDictionary:(nullable NSDictionary *)dict;
@end

typedef NS_ENUM(NSInteger, SYCompressMode) {
    SYCompressModeNone = 0,
    SYCompressModeAuto,
    SYCompressModeManual,
};

@interface SYCompressOptions : NSObject
@property (nonatomic, assign) SYCompressMode mode;
/// 1–100
@property (nonatomic, assign) NSInteger quality;
/// 0 表示不限制
@property (nonatomic, assign) NSInteger maxWidth;
/// 0 表示不限制
@property (nonatomic, assign) NSInteger maxHeight;
/// KB，源文件小于该值时跳过压缩
@property (nonatomic, assign) NSInteger minSize;
@property (nonatomic, assign) BOOL keepAlpha;

+ (instancetype)fromDictionary:(nullable NSDictionary *)dict;

/// 是否需要压缩（mode != none）。
@property (nonatomic, readonly) BOOL enabled;
/// 供编码器使用的 0–1 质量值。
- (CGFloat)jpegQuality;
@end

@interface SYImageOptions : NSObject
@property (nonatomic, assign) NSInteger maxCount;
@property (nonatomic, assign) NSInteger minCount;
/// KB，0 表示不限制
@property (nonatomic, assign) NSInteger maxFileSize;
@property (nonatomic, assign) NSInteger minFileSize;
@property (nonatomic, assign) BOOL showCameraButton;
@property (nonatomic, assign) BOOL allowGif;
@property (nonatomic, assign) BOOL allowOriginal;
@property (nonatomic, assign) BOOL includeBase64;
@property (nonatomic, assign) BOOL keepOriginal;
/// 处理期间是否显示原生 HUD，默认 YES
@property (nonatomic, assign) BOOL showLoading;
@property (nonatomic, assign) BOOL sortAscending;
@property (nonatomic, assign) BOOL showSelectionIndex;
@property (nonatomic, assign) BOOL wechatStyle;
@property (nonatomic, copy) NSArray<NSString *> *selectedUris;
@property (nonatomic, strong) SYCropOptions *crop;
@property (nonatomic, strong) SYCompressOptions *compress;
+ (instancetype)fromDictionary:(nullable NSDictionary *)dict;
@end

@interface SYVideoOptions : NSObject
/// YES 时重新编码；默认 NO，走 passthrough（快一个数量级且无损）
@property (nonatomic, assign) BOOL transcode;
/// 处理期间是否显示原生 HUD，默认 YES
@property (nonatomic, assign) BOOL showLoading;
@property (nonatomic, assign) NSInteger maxCount;
@property (nonatomic, assign) NSInteger minCount;
/// KB，0 表示不限制
@property (nonatomic, assign) NSInteger maxFileSize;
@property (nonatomic, assign) NSInteger minFileSize;
@property (nonatomic, assign) BOOL showCameraButton;
@property (nonatomic, assign) BOOL sortAscending;
@property (nonatomic, copy) NSArray<NSString *> *selectedUris;
/// 秒
@property (nonatomic, assign) NSInteger maxDuration;
@property (nonatomic, assign) NSInteger minDuration;
+ (instancetype)fromDictionary:(nullable NSDictionary *)dict;
@end

@interface SYCaptureImageOptions : NSObject
@property (nonatomic, assign) BOOL includeBase64;
@property (nonatomic, assign) BOOL keepOriginal;
@property (nonatomic, strong) SYCropOptions *crop;
@property (nonatomic, strong) SYCompressOptions *compress;
+ (instancetype)fromDictionary:(nullable NSDictionary *)dict;
@end

@interface SYCaptureVideoOptions : NSObject
/// 秒
@property (nonatomic, assign) NSInteger recordDuration;
+ (instancetype)fromDictionary:(nullable NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
