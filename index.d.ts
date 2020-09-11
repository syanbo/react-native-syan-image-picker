
export interface ImagePickerOption {
    imageCount: number,             // 最大选择图片数目，默认6
    isRecordSelected: boolean,   // 是否已选图片
    isCamera: boolean,            // 是否允许用户在内部拍照，默认true
    isCrop: boolean,             // 是否允许裁剪，默认false, imageCount 为1才生效
    CropW: number,    // 裁剪宽度，默认屏幕宽度60%
    CropH: number,    // 裁剪高度，默认屏幕宽度60%
    isGif: boolean,              // 是否允许选择GIF，默认false，暂无回调GIF数据
    showCropCircle: boolean,     // 是否显示圆形裁剪区域，默认false
    circleCropRadius: number, // 圆形裁剪半径，默认屏幕宽度一半
    showCropFrame: boolean,       // 是否显示裁剪区域，默认true
    showCropGrid: boolean,       // 是否隐藏裁剪区域网格，默认false
    freeStyleCropEnabled: boolean, // 裁剪框是否可拖拽
    rotateEnabled: boolean,       // 裁剪是否可旋转图片
    scaleEnabled: boolean,        // 裁剪是否可放大缩小图片
    compress: boolean,
    minimumCompressSize: number,  // 小于100kb的图片不压缩
    quality: number,               // 压缩质量
    enableBase64: boolean,       // 是否返回base64编码，默认不返回
    allowPickingOriginalPhoto: boolean,
    allowPickingMultipleVideo: boolean, // 可以多选视频/gif/图片，和照片共享最大可选张数maxImagesCount的限制
    videoMaximumDuration: number, // 视频最大拍摄时间，默认是10分钟，单位是秒
    isWeChatStyle: boolean,      // 是否是微信风格选择界面 Android Only
    sortAscendingByModificationDate: boolean // 对照片排序，按修改时间升序，默认是YES。如果设置为NO,最新的照片会显示在最前面，内部的拍照按钮会排在第一个
    videoCount: number // 视频个数
    MaxSecond: number // 选择视频最大时长，默认是180秒
    MinSecond: number // 选择视频最小时长，默认是1秒
    showSelectedIndex: boolean, // 是否显示序号， 默认不显示
  }

  interface SelectedPhoto {
    width: number, 	 //图片宽度
    height: number,  	//图片高度
    uri: string,	  //图片路径
    original_uri:string,	//图片原始路径，仅 Android
    type: string,	//文件类型，仅 Android，当前只返回 image
    size:number, 	 //图片大小，单位为字节 b
    base64:string	//图片的 base64 编码，如果 enableBase64 设置 false，则不返回该属性
  }

  /**
   * 以Callback形式调用
   * 1、相册参数暂时只支持默认参数中罗列的属性；
   * 2、回调形式：showImagePicker(options, (err, selectedPhotos) => {})
   *  1）选择图片成功，err为null，selectedPhotos为选中的图片数组
   *  2）取消时，err返回"取消"，selectedPhotos将为undefined
   *  按需判断各参数值，确保调用正常，示例使用方式：
   *      showImagePicker(options, (err, selectedPhotos) => {
   *          if (err) {
   *              // 取消选择
   *              return;
   *          }
   *          // 选择成功
   *      })
   *
   * @param {Object} options 相册参数
   * @param {Function} callback 成功，或失败回调
   */
  export function showImagePicker (options:Partial<ImagePickerOption>,callback:(err:null|string,photos:Array<SelectedPhoto>)=>void): void;


  /**
   * 以Promise形式调用
   * 1、相册参数暂时只支持默认参数中罗列的属性；
   * 2、使用方式
   *  1）async/await
   *  handleSelectPhoto = async () => {
   *      try {
   *          const photos = await SYImagePicker.asyncShowImagePicker(options);
   *          // 选择成功
   *      } catch (err) {
   *          // 取消选择，err.message为"取消"
   *      }
   *  }
   *  2）promise.then形式
   *  handleSelectPhoto = () => {
   *      SYImagePicker.asyncShowImagePicker(options)
   *      .then(photos => {
   *          // 选择成功
   *      })
   *      .catch(err => {
   *          // 取消选择，err.message为"取消"
   *      })
   *  }
   * @param {Object} options 相册参数
   * @return {Promise} 返回一个Promise对象
   */
  export function asyncShowImagePicker (options:Partial<ImagePickerOption>): Promise<Array<SelectedPhoto>>;

  /**
   * 打开相机支持裁剪参数
   * @param options
   * @param callback
   */
  export function openCamera (options:Partial<ImagePickerOption>,callback:(err:null|string,photos:Array<SelectedPhoto>)=>void): void;


  export function asyncOpenCamera (options:Partial<ImagePickerOption>): Promise<Array<SelectedPhoto>>;

  /**
   * 清除缓存
   */
  export function deleteCache (): void;

  /**
   * 移除选中的图片
   * @param {Number} index 要移除的图片下标
   */
  export function removePhotoAtIndex (index:number): void;

  /**
   * 移除所有选中图片
   */
  export function removeAllPhoto (): void;

  export function openVideoPicker (options:Partial<ImagePickerOption>,callback:(err:null|string,photos:Array<SelectedPhoto>)=>void): void;

