
#import "RNSyanImagePicker.h"
#import "TZImagePickerController.h"

@implementation RNSyanImagePicker

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(showImagePicker:(NSDictionary *)options
                         callback:(RCTResponseSenderBlock)callback) {
    
    //照片最大可选张数
    NSInteger imageCount = [options[@"imageCount"] integerValue];
  
    //显示内部拍照按钮
    BOOL isCamera = [options[@"isCamera"] boolValue];
    
    BOOL isCrop = [options[@"isCrop"] boolValue];
    
    NSInteger CropW = [options[@"CropW"] integerValue];
    
    NSInteger CropH = [options[@"CropH"] integerValue];
    
    BOOL isGif = [options[@"isGif"] boolValue];
    
    BOOL showCropCircle = [options[@"showCropCircle"] boolValue];
    
    
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
        
        callback(@[[NSNull null],[NSArray arrayWithArray:selectedPhotos]]);

        [weakPicker hideProgressHUD];

    }];
    
    [imagePickerVc setImagePickerControllerDidCancelHandle:^{
        callback(@[@"取消"]);
    }];
    
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:imagePickerVc animated:YES completion:nil];
    
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}


@end

