
#import "RNSyanImagePicker.h"
#import "TZImagePickerController.h"
#import "TZImageManager.h"
#import "NSDictionary+SYSafeConvert.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <React/RCTUtils.h>

@interface RNSyanImagePicker ()

@property (nonatomic, strong) UIImagePickerController *imagePickerVc;

@property (nonatomic, strong) NSDictionary *cameraOptions;

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

- (UIImagePickerController *)imagePickerVc {
    if (_imagePickerVc == nil) {
        _imagePickerVc = [[UIImagePickerController alloc] init];
        _imagePickerVc.delegate = self;
    }
    return _imagePickerVc;
}

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
    NSInteger   quality  = [self.cameraOptions sy_integerForKey:@"quality"];

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
              
              [selectedPhotos addObject:[self handleImageData:photos[0] quality:quality]];
              
          } else {
                [infos enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    
                    [selectedPhotos addObject:[self handleImageData:photos[idx] quality:quality]];
                    
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

RCT_EXPORT_METHOD(openCamera:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback) {
    self.cameraOptions = options;
    
    self.callback = callback;
    self.resolveBlock = nil;
    self.rejectBlock = nil;
    [self takePhoto];
}

#pragma mark - UIImagePickerController

- (void)takePhoto {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if ((authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) && iOS7Later) {
        // 无相机权限 做一个友好的提示
        if (iOS8Later) {
            UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
            [alert show];
        } else {
            UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alert show];
        }
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        if (iOS7Later) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self takePhoto];
                    });
                }
            }];
        } else {
            [self takePhoto];
        }
        // 拍照之前还需要检查相册权限
    } else if ([TZImageManager authorizationStatus] == 2) { // 已被拒绝，没有相册权限，将无法保存拍的照片
        if (iOS8Later) {
            UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
            [alert show];
        } else {
            UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alert show];
        }
    } else if ([TZImageManager authorizationStatus] == 0) { // 未请求过相册权限
        [[TZImageManager manager] requestAuthorizationWithCompletion:^{
            [self takePhoto];
        }];
    } else {
        [self pushImagePickerController];
    }
}

// 调用相机
- (void)pushImagePickerController {

    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        self.imagePickerVc.sourceType = sourceType;
        if(iOS8Later) {
            self.imagePickerVc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        }
        [[self topViewController] presentViewController:self.imagePickerVc animated:YES completion:nil];
       
    } else {
        NSLog(@"模拟器中无法打开照相机,请在真机中使用");
    }
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    if ([type isEqualToString:@"public.image"]) {
        
        TZImagePickerController *tzImagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:1 delegate:nil];
        tzImagePickerVc.sortAscendingByModificationDate = NO;
        [tzImagePickerVc showProgressHUD];
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        
        // save photo and get asset / 保存图片，获取到asset
        [[TZImageManager manager] savePhotoWithImage:image location:NULL completion:^(NSError *error){
            if (error) {
                [tzImagePickerVc hideProgressHUD];
                NSLog(@"图片保存失败 %@",error);
            } else {
                [[TZImageManager manager] getCameraRollAlbum:NO allowPickingImage:YES completion:^(TZAlbumModel *model) {
                    [[TZImageManager manager] getAssetsFromFetchResult:model.result allowPickingVideo:NO allowPickingImage:YES completion:^(NSArray<TZAssetModel *> *models) {
                        [tzImagePickerVc hideProgressHUD];
                        
                        TZAssetModel *assetModel = [models firstObject];
                        
                        BOOL isCrop          = [self.cameraOptions sy_boolForKey:@"isCrop"];
                        BOOL showCropCircle  = [self.cameraOptions sy_boolForKey:@"showCropCircle"];
                        NSInteger CropW      = [self.cameraOptions sy_integerForKey:@"CropW"];
                        NSInteger CropH      = [self.cameraOptions sy_integerForKey:@"CropH"];
                        NSInteger circleCropRadius = [self.cameraOptions sy_integerForKey:@"circleCropRadius"];
                        NSInteger   quality = [self.cameraOptions sy_integerForKey:@"quality"];
                        
                        if (isCrop) {
                            TZImagePickerController *imagePicker = [[TZImagePickerController alloc] initCropTypeWithAsset:assetModel.asset photo:image completion:^(UIImage *cropImage, id asset) {
                                [self invokeSuccessWithResult:@[[self handleImageData:cropImage quality:quality]]];
                            }];
                            
                            imagePicker.allowCrop = isCrop;   // 裁剪
                            if(showCropCircle) {
                                imagePicker.needCircleCrop = showCropCircle; //圆形裁剪
                                imagePicker.circleCropRadius = circleCropRadius; //圆形半径
                            } else {
                                CGFloat x = ([[UIScreen mainScreen] bounds].size.width - CropW) / 2;
                                CGFloat y = ([[UIScreen mainScreen] bounds].size.height - CropH) / 2;
                                imagePicker.cropRect = CGRectMake(x,y,CropW,CropH);
                            }
                            
                            [[self topViewController] presentViewController:imagePicker animated:YES completion:nil];
                        } else {
                            [self invokeSuccessWithResult:@[[self handleImageData:image quality:quality]]];
                        }
                        
                    }];
                }];
            }
        }];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self invokeError];
    if ([picker isKindOfClass:[UIImagePickerController class]]) {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // 去设置界面，开启相机访问权限
        if (iOS8Later) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }
    }
}

- (NSDictionary *)handleImageData:(UIImage *) image quality:(NSInteger)quality {
    NSMutableDictionary *photo = [NSMutableDictionary dictionary];
    // 剪切图片并放在tmp中
    photo[@"width"] = @(image.size.width);
    photo[@"height"] = @(image.size.height);
    
    NSString *fileName = [NSString stringWithFormat:@"%@.jpg", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [NSString stringWithFormat:@"%@/tmp/%@", NSHomeDirectory(), fileName];
    if ([UIImageJPEGRepresentation(image, quality/100) writeToFile:filePath atomically:YES]) {
        photo[@"uri"] = filePath;
    } else {
        NSLog(@"保存压缩图片失败");
    }
    
    return photo;
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
//    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    UIViewController *rootViewController = RCTPresentedViewController();
    return rootViewController;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

@end
