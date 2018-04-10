
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
/**
 保存选中的图片数组
 */
@property (nonatomic, strong) NSMutableArray *selectedAssets;
@end

@implementation RNSyanImagePicker

- (instancetype)init {
    self = [super init];
    if (self) {
        _selectedAssets = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    _selectedAssets = nil;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(showImagePicker:(NSDictionary *)options
                         callback:(RCTResponseSenderBlock)callback) {
	self.cameraOptions = options;
    self.callback = callback;
    self.resolveBlock = nil;
    self.rejectBlock = nil;
    [self openImagePicker];
}

RCT_REMAP_METHOD(asyncShowImagePicker,
                 options:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
	self.cameraOptions = options;
    self.resolveBlock = resolve;
    self.rejectBlock = reject;
    self.callback = nil;
    [self openImagePicker];
}

RCT_EXPORT_METHOD(openCamera:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback) {
    self.cameraOptions = options;
    self.callback = callback;
    self.resolveBlock = nil;
    self.rejectBlock = nil;
    [self takePhoto];
}

RCT_EXPORT_METHOD(deleteCache) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath: [NSString stringWithFormat:@"%@ImageCaches", NSTemporaryDirectory()] error:nil];
}

RCT_EXPORT_METHOD(removePhotoAtIndex:(NSInteger)index) {
    if (self.selectedAssets && self.selectedAssets.count > index) {
        [self.selectedAssets removeObjectAtIndex:index];
    }
}

RCT_EXPORT_METHOD(removeAllPhoto) {
    if (self.selectedAssets) {
        [self.selectedAssets removeAllObjects];
    }
}

- (void)openImagePicker {
    // 照片最大可选张数
    NSInteger imageCount = [self.cameraOptions sy_integerForKey:@"imageCount"];
    // 显示内部拍照按钮
    BOOL isCamera        = [self.cameraOptions sy_boolForKey:@"isCamera"];
    BOOL isCrop          = [self.cameraOptions sy_boolForKey:@"isCrop"];
    BOOL isGif           = [self.cameraOptions sy_boolForKey:@"isGif"];
    BOOL showCropCircle  = [self.cameraOptions sy_boolForKey:@"showCropCircle"];
    BOOL isRecordSelected = [self.cameraOptions sy_boolForKey:@"isRecordSelected"];
    NSInteger CropW      = [self.cameraOptions sy_integerForKey:@"CropW"];
    NSInteger CropH      = [self.cameraOptions sy_integerForKey:@"CropH"];
    NSInteger circleCropRadius = [self.cameraOptions sy_integerForKey:@"circleCropRadius"];
    NSInteger   quality  = [self.cameraOptions sy_integerForKey:@"quality"];

    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:imageCount delegate:nil];

    imagePickerVc.maxImagesCount = imageCount;
    imagePickerVc.allowPickingGif = isGif; // 允许GIF
    imagePickerVc.allowTakePicture = isCamera; // 允许用户在内部拍照
    imagePickerVc.allowPickingVideo = NO; // 不允许视频
    imagePickerVc.allowPickingOriginalPhoto = NO; // 允许原图
    imagePickerVc.alwaysEnableDoneBtn = YES;
    imagePickerVc.allowCrop = isCrop;   // 裁剪

    if (isRecordSelected) {
        imagePickerVc.selectedAssets = self.selectedAssets; // 当前已选中的图片
    }

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
        if (isRecordSelected) {
            self.selectedAssets = [NSMutableArray arrayWithArray:assets];
        }
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

    __block TZImagePickerController *weakPickerVc = imagePickerVc;
    [imagePickerVc setImagePickerControllerDidCancelHandle:^{
        [self invokeError];
        [weakPickerVc hideProgressHUD];
    }];

    [[self topViewController] presentViewController:imagePickerVc animated:YES completion:nil];
}

- (UIImagePickerController *)imagePickerVc {
    if (_imagePickerVc == nil) {
        _imagePickerVc = [[UIImagePickerController alloc] init];
        _imagePickerVc.delegate = self;
    }
    return _imagePickerVc;
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
    [picker dismissViewControllerAnimated:YES completion:^{
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
                    [[TZImageManager manager] getCameraRollAlbum:NO allowPickingImage:YES needFetchAssets:YES completion:^(TZAlbumModel *model) {
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
    }];
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
	NSData *imageData = UIImageJPEGRepresentation(image, quality * 1.0 / 100);

    // 剪切图片并放在tmp中
    photo[@"width"] = @(image.size.width);
    photo[@"height"] = @(image.size.height);
	photo[@"size"] = @(imageData.length);

    NSString *fileName = [NSString stringWithFormat:@"%@.jpg", [[NSUUID UUID] UUIDString]];
    [self createDir];
    NSString *filePath = [NSString stringWithFormat:@"%@ImageCaches/%@", NSTemporaryDirectory(), fileName];
    if ([imageData writeToFile:filePath atomically:YES]) {
        photo[@"uri"] = filePath;
    } else {
        NSLog(@"保存压缩图片失败%@", filePath);
    }

    if ([self.cameraOptions sy_boolForKey:@"enableBase64"]) {
        photo[@"base64"] = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", [imageData base64EncodedStringWithOptions:0]];
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

- (BOOL)createDir {
    NSString * path = [NSString stringWithFormat:@"%@ImageCaches", NSTemporaryDirectory()];;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if  (![fileManager fileExistsAtPath:path isDirectory:&isDir]) {//先判断目录是否存在，不存在才创建
        BOOL res=[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        return res;
    } else return NO;
}

- (UIViewController *)topViewController {
    UIViewController *rootViewController = RCTPresentedViewController();
    return rootViewController;
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

@end
