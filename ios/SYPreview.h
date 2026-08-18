#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 本地文件全屏预览。

 不用 TZImagePickerController 的预览入口：那个初始化方法会按 selectedAssets
 填 models，我们手里只有缓存文件 UIImage，传空 assets 会在
 TZPhotoPreviewController.refreshNaviBarAndBottomBarState 里越界崩溃。
 */
@interface SYPreviewController : UIViewController

- (instancetype)initWithImages:(NSArray<UIImage *> *)images
                    startIndex:(NSInteger)startIndex;

@end

NS_ASSUME_NONNULL_END
