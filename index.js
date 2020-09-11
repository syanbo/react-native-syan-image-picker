import {
    NativeModules,
    Dimensions,
} from 'react-native';

const { RNSyanImagePicker } = NativeModules;

const { width } = Dimensions.get('window');
/**
 * 默认参数
 */
const defaultOptions = {
    imageCount: 6,             // 最大选择图片数目，默认6
    isRecordSelected: false,   // 是否已选图片
    isCamera: true,            // 是否允许用户在内部拍照，默认true
    isCrop: false,             // 是否允许裁剪，默认false, imageCount 为1才生效
    CropW: ~~(width * 0.6),    // 裁剪宽度，默认屏幕宽度60%
    CropH: ~~(width * 0.6),    // 裁剪高度，默认屏幕宽度60%
    isGif: false,              // 是否允许选择GIF，默认false，暂无回调GIF数据
    showCropCircle: false,     // 是否显示圆形裁剪区域，默认false
    circleCropRadius: ~~(width / 4), // 圆形裁剪半径，默认屏幕宽度一半
    showCropFrame: true,       // 是否显示裁剪区域，默认true
    showCropGrid: false,       // 是否隐藏裁剪区域网格，默认false
    freeStyleCropEnabled: false, // 裁剪框是否可拖拽
    rotateEnabled: true,       // 裁剪是否可旋转图片
    scaleEnabled: true,        // 裁剪是否可放大缩小图片
    compress: true,
    minimumCompressSize: 100,  // 小于100kb的图片不压缩
    quality: 90,               // 压缩质量
    enableBase64: false,       // 是否返回base64编码，默认不返回
    allowPickingOriginalPhoto: false,
    allowPickingMultipleVideo: false, // 可以多选视频/gif/图片，和照片共享最大可选张数maxImagesCount的限制
    videoMaximumDuration: 10 * 60, // 视频最大拍摄时间，默认是10分钟，单位是秒
    isWeChatStyle: false,      // 是否是微信风格选择界面 Android Only
    sortAscendingByModificationDate: true, // 对照片排序，按修改时间升序，默认是YES。如果设置为NO,最新的照片会显示在最前面，内部的拍照按钮会排在第一个
    showSelectedIndex: false, // 是否显示序号， 默认不显示
};

export default {
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
    showImagePicker(options, callback) {
        const optionObj = {
            ...defaultOptions,
            ...options
        };
        RNSyanImagePicker.showImagePicker(optionObj, callback)
    },

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
    asyncShowImagePicker(options) {
        const optionObj = {
            ...defaultOptions,
            ...options,
        };
        return RNSyanImagePicker.asyncShowImagePicker(optionObj);
    },

    /**
     * 打开相机支持裁剪参数
     * @param options
     * @param callback
     */
    openCamera(options, callback) {
        const optionObj = {
            ...defaultOptions,
            ...options
        };
        RNSyanImagePicker.openCamera(optionObj, callback)
    },

    asyncOpenCamera(options) {
        const optionObj = {
            ...defaultOptions,
            ...options,
        };
        return RNSyanImagePicker.asyncOpenCamera(optionObj);
    },

    /**
     * 清除缓存
     */
    deleteCache() {
        RNSyanImagePicker.deleteCache()
    },

    /**
     * 移除选中的图片
     * @param {Number} index 要移除的图片下标
     */
    removePhotoAtIndex(index) {
        RNSyanImagePicker.removePhotoAtIndex(index)
    },

    /**
     * 移除所有选中图片
     */
    removeAllPhoto() {
        RNSyanImagePicker.removeAllPhoto()
    },

    openVideoPicker(options, callback) {
        const imageCount = options.videoCount ? options.videoCount : 1
        const optionObj = {
            ...defaultOptions,
            isCamera: false,
            allowPickingGif: false,
            allowPickingVideo: true,
            allowPickingImage: false,
            allowTakeVideo: true,
            allowPickingMultipleVideo: imageCount > 1,
            videoMaximumDuration: 20,
            MaxSecond: 60,
            MinSecond: 0,
            recordVideoSecond: 60,
            ...options,
            imageCount
        };
        return RNSyanImagePicker.openVideoPicker(optionObj, callback)
    }
};
