#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

/**
 公开头文件刻意保持最小。

 老实现在这里 `#import "TZImagePickerController.h"` 并声明了一堆 TZ / UIKit 的
 delegate 一致性 —— 在 `use_frameworks!` 或开启 modular headers 的工程里，这会
 直接导致头文件解析失败。所有第三方类型都收进 .m 的 class extension 里。
 */
/**
 继承 RCTEventEmitter 是为了发送处理进度事件。没有监听者时不会发任何东西
 （见 startObserving / stopObserving），因此不订阅的调用方零开销。
 */
@interface RNSyanImagePicker : RCTEventEmitter <RCTBridgeModule>

/**
 宿主自定义选择器外观：传入 TZImagePickerController 的子类，相册和视频选择都用它创建。
 子类在指定初始化方法 initWithMaxImagesCount:columnNumber:delegate:pushPhotoPickerVc: 里设置外观
 （本库用 initWithMaxImagesCount:delegate: 创建，TZ 3.8 会直接走到它）；本库随后设置的选项仍然生效。
 参数用 Class 而不是具体类型，是为了公开头文件不引入 TZ（理由见上）。传 nil 或非子类时恢复默认。
 */
+ (void)setPickerClass:(nullable Class)pickerClass;

@end
