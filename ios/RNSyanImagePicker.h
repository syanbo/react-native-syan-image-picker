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

@end
