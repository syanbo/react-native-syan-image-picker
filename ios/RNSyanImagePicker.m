
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
                 showImagePickerResolver:(RCTPromiseResolveBlock)resolve
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

RCT_REMAP_METHOD(asyncOpenCamera,
                 options:(NSDictionary *)options
                 openCameraResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
  self.cameraOptions = options;
  self.resolveBlock = resolve;
  self.rejectBlock = reject;
  self.callback = nil;
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

// openVideoPicker
RCT_EXPORT_METHOD(openVideoPicker:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback) {
    [self openTZImagePicker:options callback:callback];
}

- (void)openTZImagePicker:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback {
    NSInteger imageCount = [options sy_integerForKey:@"imageCount"];
    BOOL isCamera        = [options sy_boolForKey:@"isCamera"];
    BOOL isCrop          = [options sy_boolForKey:@"isCrop"];
    BOOL allowPickingGif = [options sy_boolForKey:@"allowPickingGif"];
    BOOL allowPickingVideo = [options sy_boolForKey:@"allowPickingVideo"];
    BOOL allowPickingMultipleVideo = [options sy_boolForKey:@"allowPickingMultipleVideo"];
    BOOL allowPickingImage = [options sy_boolForKey:@"allowPickingImage"];
    BOOL showCropCircle  = [options sy_boolForKey:@"showCropCircle"];
    BOOL isRecordSelected = [options sy_boolForKey:@"isRecordSelected"];
    BOOL allowPickingOriginalPhoto = [options sy_boolForKey:@"allowPickingOriginalPhoto"];
    BOOL sortAscendingByModificationDate = [options sy_boolForKey:@"sortAscendingByModificationDate"];
    NSInteger CropW      = [options sy_integerForKey:@"CropW"];
    NSInteger CropH      = [options sy_integerForKey:@"CropH"];
    NSInteger circleCropRadius = [options sy_integerForKey:@"circleCropRadius"];
    NSInteger videoMaximumDuration = [options sy_integerForKey:@"videoMaximumDuration"];

    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:imageCount delegate:nil];

    imagePickerVc.maxImagesCount = imageCount;
    imagePickerVc.allowPickingGif = allowPickingGif; // 允许GIF
    imagePickerVc.allowTakePicture = isCamera; // 允许用户在内部拍照
    imagePickerVc.allowPickingVideo = allowPickingVideo; // 不允许视频
    imagePickerVc.allowPickingImage = allowPickingImage;
    imagePickerVc.allowTakeVideo = NO;
    imagePickerVc.videoMaximumDuration = videoMaximumDuration;
    imagePickerVc.allowPickingMultipleVideo = allowPickingMultipleVideo;
    imagePickerVc.allowPickingOriginalPhoto = allowPickingOriginalPhoto; // 允许原图
    imagePickerVc.sortAscendingByModificationDate = sortAscendingByModificationDate;
    imagePickerVc.alwaysEnableDoneBtn = YES;
    imagePickerVc.allowCrop = isCrop;   // 裁剪
    imagePickerVc.autoDismiss = NO;

    if (isRecordSelected) {
        imagePickerVc.selectedAssets = self.selectedAssets; // 当前已选中的图片
    }

    if (imageCount == 1) {
        // 单选模式
        imagePickerVc.showSelectBtn = NO;

        if(isCrop){
            if(showCropCircle) {
                imagePickerVc.needCircleCrop = showCropCircle; //圆形裁剪
                imagePickerVc.circleCropRadius = circleCropRadius; //圆形半径
            } else {
                CGFloat x = ([[UIScreen mainScreen] bounds].size.width - CropW) / 2;
                CGFloat y = ([[UIScreen mainScreen] bounds].size.height - CropH) / 2;
                imagePickerVc.cropRect = CGRectMake(x,y,CropW,CropH);
            }
        }
    }

    __weak TZImagePickerController *weakPicker = imagePickerVc;
    [imagePickerVc setDidFinishPickingPhotosWithInfosHandle:^(NSArray<UIImage *> *photos,NSArray *assets,BOOL isSelectOriginalPhoto,NSArray<NSDictionary *> *infos) {
        NSMutableArray *selectArray = [NSMutableArray array];
        for (NSInteger i = 0; i < assets.count; i++) {
            PHAsset *asset = assets[i];
            [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPreset640x480 success:^(NSString *outputPath) {
                NSMutableDictionary *video = [NSMutableDictionary dictionary];
                video[@"uri"] = outputPath;
                video[@"fileName"] = [asset valueForKey:@"filename"];
                NSInteger size = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:nil].fileSize;
                video[@"size"] = @(size);
                if (asset.mediaType == PHAssetMediaTypeVideo) {
                    video[@"type"] = @"video";
                }
                video[@"duration"] = @(asset.duration);
                NSData *imageData = UIImagePNGRepresentation(photos[i]);
                NSString *fileName = [NSString stringWithFormat:@"%@.png", [[NSUUID UUID] UUIDString]];
                [self createDir];
                NSString *filePath = [NSString stringWithFormat:@"%@ImageCaches/%@", NSTemporaryDirectory(), fileName];
                if ([imageData writeToFile:filePath atomically:YES]) {
                    video[@"coverUri"] = filePath;
                }
                [selectArray addObject:video];
                if(selectArray.count == assets.count) {
                    callback(@[[NSNull null], selectArray]);
                    [weakPicker dismissViewControllerAnimated:YES completion:nil];
                    [weakPicker hideProgressHUD];
                }

            } failure:^(NSString *errorMessage, NSError *error) {
                NSLog(@"视频导出失败:%@,error:%@",errorMessage, error);
                [weakPicker dismissViewControllerAnimated:YES completion:nil];
                [weakPicker hideProgressHUD];
            }];
        }
    }];

    [imagePickerVc setDidFinishPickingVideoHandle:^(UIImage *coverImage, PHAsset *asset) {
        [weakPicker showProgressHUD];
        [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPreset640x480 success:^(NSString *outputPath) {
            NSLog(@"视频导出到本地完成,沙盒路径为:%@",outputPath);
            NSMutableDictionary *video = [NSMutableDictionary dictionary];
            video[@"uri"] = outputPath;
            video[@"fileName"] = [asset valueForKey:@"filename"];
            NSInteger size = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:nil].fileSize;
            video[@"size"] = @(size);
            if (asset.mediaType == PHAssetMediaTypeVideo) {
                video[@"type"] = @"video";
            }
            video[@"duration"] = @(asset.duration);
            NSData *imageData = UIImagePNGRepresentation(coverImage);
            NSString *fileName = [NSString stringWithFormat:@"%@.png", [[NSUUID UUID] UUIDString]];
            [self createDir];
            NSString *filePath = [NSString stringWithFormat:@"%@ImageCaches/%@", NSTemporaryDirectory(), fileName];
            if ([imageData writeToFile:filePath atomically:YES]) {
                video[@"coverUri"] = filePath;
            }
            callback(@[[NSNull null], @[video]]);
            [weakPicker dismissViewControllerAnimated:YES completion:nil];
            [weakPicker hideProgressHUD];
        } failure:^(NSString *errorMessage, NSError *error) {
            NSLog(@"视频导出失败:%@,error:%@",errorMessage, error);
            callback(@[@"视频导出失败"]);
            [weakPicker dismissViewControllerAnimated:YES completion:nil];
            [weakPicker hideProgressHUD];
        }];
    }];

    __weak TZImagePickerController *weakPickerVc = imagePickerVc;
    [imagePickerVc setImagePickerControllerDidCancelHandle:^{
        callback(@[@"取消"]);
        [weakPicker dismissViewControllerAnimated:YES completion:nil];
        [weakPickerVc hideProgressHUD];
    }];

    [[self topViewController] presentViewController:imagePickerVc animated:YES completion:nil];
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
    BOOL allowPickingOriginalPhoto = [self.cameraOptions sy_boolForKey:@"allowPickingOriginalPhoto"];
    BOOL sortAscendingByModificationDate = [self.cameraOptions sy_boolForKey:@"sortAscendingByModificationDate"];
    NSInteger CropW      = [self.cameraOptions sy_integerForKey:@"CropW"];
    NSInteger CropH      = [self.cameraOptions sy_integerForKey:@"CropH"];
    NSInteger circleCropRadius = [self.cameraOptions sy_integerForKey:@"circleCropRadius"];
    NSInteger   quality  = [self.cameraOptions sy_integerForKey:@"quality"];

    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:imageCount delegate:nil];

    imagePickerVc.maxImagesCount = imageCount;
    imagePickerVc.allowPickingGif = isGif; // 允许GIF
    imagePickerVc.allowTakePicture = isCamera; // 允许用户在内部拍照
    imagePickerVc.allowPickingVideo = NO; // 不允许视频
    imagePickerVc.allowPickingOriginalPhoto = allowPickingOriginalPhoto; // 允许原图
    imagePickerVc.sortAscendingByModificationDate = sortAscendingByModificationDate;
    imagePickerVc.alwaysEnableDoneBtn = YES;
    imagePickerVc.allowCrop = isCrop;   // 裁剪

    if (isRecordSelected) {
        imagePickerVc.selectedAssets = self.selectedAssets; // 当前已选中的图片
    }

    if (imageCount == 1) {
        // 单选模式
        imagePickerVc.showSelectBtn = NO;

        if(isCrop){
            if(showCropCircle) {
                imagePickerVc.needCircleCrop = showCropCircle; //圆形裁剪
                imagePickerVc.circleCropRadius = circleCropRadius; //圆形半径
            } else {
                CGFloat x = ([[UIScreen mainScreen] bounds].size.width - CropW) / 2;
                CGFloat y = ([[UIScreen mainScreen] bounds].size.height - CropH) / 2;
                imagePickerVc.cropRect = CGRectMake(x,y,CropW,CropH);
            }
        }
    }

    __weak TZImagePickerController *weakPicker = imagePickerVc;
    [imagePickerVc setDidFinishPickingPhotosWithInfosHandle:^(NSArray<UIImage *> *photos,NSArray *assets,BOOL isSelectOriginalPhoto,NSArray<NSDictionary *> *infos) {
        if (isRecordSelected) {
            self.selectedAssets = [NSMutableArray arrayWithArray:assets];
        }
        NSMutableArray *selectedPhotos = [NSMutableArray array];
        [weakPicker showProgressHUD];
        if (imageCount == 1 && isCrop) {
            //增加png保留透明度功能
            [selectedPhotos addObject:[self handleImageData:photos[0] info:infos[0] quality:quality]];
        } else {
            [infos enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                //增加png保留透明度功能
                [selectedPhotos addObject:[self handleImageData:photos[idx] info:infos[idx] quality:quality]];
                
            }];
        }
        [self invokeSuccessWithResult:selectedPhotos];
        [weakPicker hideProgressHUD];
    }];

    __weak TZImagePickerController *weakPickerVc = imagePickerVc;
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
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
        // 无相机权限 做一个友好的提示
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
        [alert show];
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self takePhoto];
                });
            }
        }];
        // 拍照之前还需要检查相册权限
    } else if ([PHPhotoLibrary authorizationStatus] == 2) { // 已被拒绝，没有相册权限，将无法保存拍的照片
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
        [alert show];
    } else if ([PHPhotoLibrary authorizationStatus] == 0) { // 未请求过相册权限
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
            [[TZImageManager manager] savePhotoWithImage:image location:NULL completion:^(PHAsset *asset, NSError *error){
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
                                imagePicker.allowPickingImage = YES;
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
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
}

/**
 保留png透明度的回调方法
 通过文件后缀判断是否是png
 */
- (NSDictionary *)handleImageData:(UIImage *) image info:(NSDictionary *)info quality:(NSInteger)quality {
    NSMutableDictionary *photo = [NSMutableDictionary dictionary];
    
    NSString *filePath = [NSString stringWithFormat:@"%@",info[@"PHImageFileURLKey"]];
    NSRange range = [[filePath lowercaseString] rangeOfString:@".png"];
    BOOL isPng = range.length > 0 ? YES : NO;
    NSLog(@"++%@",isPng?@"is png":@"not png");
    // 建议增加配置项选择是否放弃png透明度 提高压缩率
    if(isPng == NO){
        return [self handleImageData:image quality:quality];
    }
    NSData *imageData = UIImagePNGRepresentation(image);
    //无需压缩 所以不需要保存临时文件直接返回原图地址  ？？？？？
    photo[@"uri"] = filePath;
    photo[@"width"] = @(image.size.width);
    photo[@"height"] = @(image.size.height);
    photo[@"size"] = @(imageData.length);
    
    if ([self.cameraOptions sy_boolForKey:@"enableBase64"]) {
        photo[@"base64"] = isPng?[NSString stringWithFormat:@"data:image/png;base64,%@", [imageData base64EncodedStringWithOptions:0]]:[NSString stringWithFormat:@"data:image/jpeg;base64,%@", [imageData base64EncodedStringWithOptions:0]];
    }
    return photo;
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

+ (BOOL)requiresMainQueueSetup
{
   return YES;
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
