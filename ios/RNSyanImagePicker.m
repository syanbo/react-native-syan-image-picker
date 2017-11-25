
#import "RNSyanImagePicker.h"
#import "TZImagePickerController.h"
#import "NSDictionary+SYSafeConvert.h"

@interface RNSyanImagePicker ()
/**
 保存Promise的resolve block
 */
@property (nonatomic, copy) RCTPromiseResolveBlock resolveBlock;
/**
 保存Promise的reject block
 */
@property (nonatomic, copy) RCTPromiseRejectBlock rejectBlock;
/**
 保存回调的callback
 */
@property (nonatomic, copy) RCTResponseSenderBlock callback;
@end

@implementation RNSyanImagePicker

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(showImagePicker:(NSDictionary *)options
                         callback:(RCTResponseSenderBlock)callback) {
    self.callback = callback;
    self.resolveBlock = nil;
    self.rejectBlock = nil;
    [self openImagePickerWithOptions:options];
}

RCT_REMAP_METHOD(asyncShowImagePicker,
                 options:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    self.resolveBlock = resolve;
    self.rejectBlock = reject;
    self.callback = nil;
    [self openImagePickerWithOptions:options];
}

- (void)openImagePickerWithOptions:(NSDictionary *)options {
    // 照片最大可选张数
    NSInteger imageCount = [options sy_integerForKey:@"imageCount"];
    // 显示内部拍照按钮
    BOOL isCamera        = [options sy_boolForKey:@"isCamera"];
    BOOL isCrop          = [options sy_boolForKey:@"isCrop"];
    BOOL isGif           = [options sy_boolForKey:@"isGif"];
    BOOL showCropCircle  = [options sy_boolForKey:@"showCropCircle"];
    NSInteger CropW      = [options sy_integerForKey:@"CropW"];
    NSInteger CropH      = [options sy_integerForKey:@"CropH"];
    NSInteger circleCropRadius = [options sy_integerForKey:@"circleCropRadius"];

    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:imageCount delegate:nil];

    imagePickerVc.maxImagesCount = imageCount;
    imagePickerVc.allowPickingGif = isGif; // 允许GIF
    imagePickerVc.allowTakePicture = isCamera; // 允许用户在内部拍照
    imagePickerVc.allowPickingVideo = NO; // 不允许视频
    imagePickerVc.allowPickingOriginalPhoto = NO; // 允许原图
    imagePickerVc.allowCrop = isCrop;   // 裁剪

    if (imageCount == 1) {
        // 单选模式
        imagePickerVc.showSelectBtn = NO;
        imagePickerVc.allowPreview = NO;

        if(isCrop){
            if(showCropCircle) {
                imagePickerVc.needCircleCrop = showCropCircle; //圆形裁剪
                imagePickerVc.circleCropRadius = circleCropRadius; //圆形半径
            } else {
                CGFloat x = ([[UIScreen mainScreen] bounds].size.width - CropW) / 2;
                CGFloat y = ([[UIScreen mainScreen] bounds].size.height - CropH) / 2;
                imagePickerVc.cropRect = imagePickerVc.cropRect = CGRectMake(x,y,CropW,CropH);
            }
        }
    }
  
    __block TZImagePickerController *weakPicker = imagePickerVc;
    [imagePickerVc setDidFinishPickingPhotosWithInfosHandle:^(NSArray<UIImage *> *photos,NSArray *assets,BOOL isSelectOriginalPhoto,NSArray<NSDictionary *> *infos) {
          NSMutableArray *selectedPhotos = [NSMutableArray array];
          [weakPicker showProgressHUD];
      
          if (imageCount == 1 && isCrop) {
              NSMutableDictionary *photo = [NSMutableDictionary dictionary];
              // 剪切图片并放在tmp中
              photo[@"width"] = @(photos[0].size.width);
              photo[@"height"] = @(photos[0].size.height);
            
              NSString *fileName = [NSString stringWithFormat:@"%d.jpg", arc4random() % 10000000];
              NSString *filePath = [NSString stringWithFormat:@"%@/tmp/%@", NSHomeDirectory(), fileName];
              if ([UIImageJPEGRepresentation(photos[0], 0.9) writeToFile:filePath atomically:YES]) {
                  photo[@"uri"] = filePath;
              } else {
                  NSLog(@"保存压缩图片失败");
              }
            
              [selectedPhotos addObject:photo];

        } else {
            [infos enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSMutableDictionary *photo = [NSMutableDictionary dictionary];
                photo[@"width"] = @(photos[idx].size.width);
                photo[@"height"] = @(photos[idx].size.height);
                photo[@"original_uri"] = [(NSURL *)obj[@"PHImageFileURLKey"] absoluteString];
              
                NSString *fileName = [NSString stringWithFormat:@"%d.jpg", arc4random() % 10000000];
                NSString *filePath = [NSString stringWithFormat:@"%@/tmp/%@", NSHomeDirectory(), fileName];
                if ([UIImageJPEGRepresentation(photos[idx], 0.9) writeToFile:filePath atomically:YES]) {
                    photo[@"uri"] = filePath;
                } else {
                    NSLog(@"保存压缩图片失败");
                }
              
                [selectedPhotos addObject:photo];
            }];
        }
      
        [self invokeSuccessWithResult:selectedPhotos];
      
        [weakPicker hideProgressHUD];
    }];
  
    [imagePickerVc setImagePickerControllerDidCancelHandle:^{
        [self invokeError];
    }];
  
    [[self topViewController] presentViewController:imagePickerVc animated:YES completion:nil];
}

- (void)invokeSuccessWithResult:(NSArray *)photos {
    if (self.callback) {
        self.callback(@[[NSNull null], photos]);
        self.callback = nil;
    }
    if (self.resolveBlock) {
        self.resolveBlock(photos);
        self.resolveBlock = nil;
    }
}

- (void)invokeError {
    if (self.callback) {
        self.callback(@[@"取消"]);
        self.callback = nil;
    }
    if (self.rejectBlock) {
        self.rejectBlock(@"", @"取消", nil);
        self.rejectBlock = nil;
    }
}

- (UIViewController *)topViewController {
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    if (rootViewController.presentedViewController) {
        rootViewController = rootViewController.presentedViewController;
    }
    return rootViewController;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

@end