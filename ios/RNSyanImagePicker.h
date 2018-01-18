
#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif
#import <UIKit/UIKit.h>
@interface RNSyanImagePicker : NSObject <RCTBridgeModule, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIActionSheetDelegate>

@end
  
