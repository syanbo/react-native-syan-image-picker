#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 栈顶 presenter 当前是否还能再 present。

 不要检查 presentedViewController：RCTPresentedViewController() 已经走到栈顶，
 那条判断几乎永远为假。
 */
BOOL SYPresenterIsReady(UIViewController *_Nullable presenter);

/// 先判 ready，再 @try present。失败时写入 error（可空）。
BOOL SYPresentViewController(UIViewController *_Nullable presenter,
                             UIViewController *child,
                             NSError *_Nullable *_Nullable error);

NS_ASSUME_NONNULL_END
