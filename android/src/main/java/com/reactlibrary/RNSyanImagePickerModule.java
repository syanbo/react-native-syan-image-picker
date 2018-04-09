
package com.reactlibrary;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Base64;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.luck.picture.lib.PictureSelector;
import com.luck.picture.lib.config.PictureConfig;
import com.luck.picture.lib.config.PictureMimeType;
import com.luck.picture.lib.entity.LocalMedia;
import com.luck.picture.lib.tools.PictureFileUtils;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.List;

public class RNSyanImagePickerModule extends ReactContextBaseJavaModule {

    private static String SY_SELECT_IMAGE_FAILED_CODE = "0"; // 失败时，Promise用到的code

    private final ReactApplicationContext reactContext;

    private List<LocalMedia> selectList = new ArrayList<>();

    private Callback mPickerCallback; // 保存回调

    private Promise mPickerPromise; // 保存Promise

    private ReadableMap cameraOptions; // 保存图片选择/相机选项

    public RNSyanImagePickerModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        reactContext.addActivityEventListener(mActivityEventListener);
    }

    @Override
    public String getName() {
        return "RNSyanImagePicker";
    }

    @ReactMethod
    public void showImagePicker(ReadableMap options, Callback callback) {
        this.cameraOptions = options;
        this.mPickerPromise = null;
        this.mPickerCallback = callback;
        this.openImagePicker();
    }

    @ReactMethod
    public void asyncShowImagePicker(ReadableMap options, Promise promise) {
        this.cameraOptions = options;
        this.mPickerCallback = null;
        this.mPickerPromise = promise;
        this.openImagePicker();
    }

    @ReactMethod
    public void openCamera(ReadableMap options, Callback callback) {
        this.cameraOptions = options;
        this.mPickerPromise = null;
        this.mPickerCallback = callback;
        this.openCamera();
    }

    /**
     * 缓存清除
     * 包括裁剪和压缩后的缓存，要在上传成功后调用，注意：需要系统sd卡权限
     */
    @ReactMethod
    public void deleteCache() {
        Activity currentActivity = getCurrentActivity();
        PictureFileUtils.deleteCacheDirFile(currentActivity);
    }

    /**
     * 移除选中的图片
     * @param {int} index 要移除的图片下标
     */
    @ReactMethod
    public void removePhotoAtIndex(int index) {
        if (selectList != null && selectList.size() > index) {
            selectList.remove(index);
        }
    }

    /**
     * 移除所有选中的图片
     */
    @ReactMethod
    public void removeAllPhoto() {
        if (selectList != null) {
            //selectList.clear();
            selectList = null;
        }
    }

    /**
     * 打开相册选择
     */
    private void openImagePicker() {
        int imageCount = this.cameraOptions.getInt("imageCount");
        boolean isCamera = this.cameraOptions.getBoolean("isCamera");
        boolean isCrop = this.cameraOptions.getBoolean("isCrop");
        int CropW = this.cameraOptions.getInt("CropW");
        int CropH = this.cameraOptions.getInt("CropH");
        boolean isGif = this.cameraOptions.getBoolean("isGif");
        boolean showCropCircle = this.cameraOptions.getBoolean("showCropCircle");
        boolean showCropFrame = this.cameraOptions.getBoolean("showCropFrame");
        boolean showCropGrid = this.cameraOptions.getBoolean("showCropGrid");
        int quality = this.cameraOptions.getInt("quality");

        int modeValue;
        if (imageCount == 1) {
            modeValue = 1;
        } else {
            modeValue = 2;
        }
        Activity currentActivity = getCurrentActivity();
        PictureSelector.create(currentActivity)
                .openGallery(PictureMimeType.ofImage())//全部.PictureMimeType.ofAll()、图片.ofImage()、视频.ofVideo()、音频.ofAudio()
                .maxSelectNum(imageCount)// 最大图片选择数量 int
                .minSelectNum(0)// 最小选择数量 int
                .imageSpanCount(4)// 每行显示个数 int
                .selectionMode(modeValue)// 多选 or 单选 PictureConfig.MULTIPLE or PictureConfig.SINGLE
                .previewImage(true)// 是否可预览图片 true or false
                .previewVideo(false)// 是否可预览视频 true or false
                .enablePreviewAudio(false) // 是否可播放音频 true or false
                .isCamera(isCamera)// 是否显示拍照按钮 true or false
                .imageFormat(PictureMimeType.PNG)// 拍照保存图片格式后缀,默认jpeg
                .isZoomAnim(true)// 图片列表点击 缩放效果 默认true
                .sizeMultiplier(0.5f)// glide 加载图片大小 0~1之间 如设置 .glideOverride()无效
                .enableCrop(isCrop)// 是否裁剪 true or false
                .compress(true)// 是否压缩 true or false
                .glideOverride(160, 160)// int glide 加载宽高，越小图片列表越流畅，但会影响列表图片浏览的清晰度
                .withAspectRatio(CropW, CropH)// int 裁剪比例 如16:9 3:2 3:4 1:1 可自定义
                .hideBottomControls(isCrop)// 是否显示uCrop工具栏，默认不显示 true or false
                .isGif(isGif)// 是否显示gif图片 true or false
                .freeStyleCropEnabled(true)// 裁剪框是否可拖拽 true or false
                .circleDimmedLayer(showCropCircle)// 是否圆形裁剪 true or false
                .showCropFrame(showCropFrame)// 是否显示裁剪矩形边框 圆形裁剪时建议设为false   true or false
                .showCropGrid(showCropGrid)// 是否显示裁剪矩形网格 圆形裁剪时建议设为false    true or false
                .openClickSound(false)// 是否开启点击声音 true or false
                .cropCompressQuality(quality)// 裁剪压缩质量 默认90 int
                .minimumCompressSize(100)// 小于100kb的图片不压缩
                .synOrAsy(true)//同步true或异步false 压缩 默认同步
                .rotateEnabled(true) // 裁剪是否可旋转图片 true or false
                .scaleEnabled(true)// 裁剪是否可放大缩小图片 true or false
                .selectionMedia(selectList) // 当前已选中的图片 List
                //.videoQuality(0)// 视频录制质量 0 or 1 int
                //.videoMaxSecond(15)// 显示多少秒以内的视频or音频也可适用 int
                //.videoMinSecond(10)// 显示多少秒以内的视频or音频也可适用 int
                //.recordVideoSecond(60)//视频秒数录制 默认60s int
                .forResult(PictureConfig.CHOOSE_REQUEST);//结果回调onActivityResult code
    }

    /**
     * 打开相机
     */
    private void openCamera() {
        boolean isCrop = this.cameraOptions.getBoolean("isCrop");
        int CropW = this.cameraOptions.getInt("CropW");
        int CropH = this.cameraOptions.getInt("CropH");
        boolean showCropCircle = this.cameraOptions.getBoolean("showCropCircle");
        boolean showCropFrame = this.cameraOptions.getBoolean("showCropFrame");
        boolean showCropGrid = this.cameraOptions.getBoolean("showCropGrid");
        int quality = this.cameraOptions.getInt("quality");

        Activity currentActivity = getCurrentActivity();
        PictureSelector.create(currentActivity)
                .openCamera(PictureMimeType.ofImage())
                .imageFormat(PictureMimeType.PNG)// 拍照保存图片格式后缀,默认jpeg
                .enableCrop(isCrop)// 是否裁剪 true or false
                .compress(true)// 是否压缩 true or false
                .glideOverride(160, 160)// int glide 加载宽高，越小图片列表越流畅，但会影响列表图片浏览的清晰度
                .withAspectRatio(CropW, CropH)// int 裁剪比例 如16:9 3:2 3:4 1:1 可自定义
                .hideBottomControls(isCrop)// 是否显示uCrop工具栏，默认不显示 true or false
                .freeStyleCropEnabled(true)// 裁剪框是否可拖拽 true or false
                .circleDimmedLayer(showCropCircle)// 是否圆形裁剪 true or false
                .showCropFrame(showCropFrame)// 是否显示裁剪矩形边框 圆形裁剪时建议设为false   true or false
                .showCropGrid(showCropGrid)// 是否显示裁剪矩形网格 圆形裁剪时建议设为false    true or false
                .openClickSound(false)// 是否开启点击声音 true or false
                .cropCompressQuality(quality)// 裁剪压缩质量 默认90 int
                .minimumCompressSize(100)// 小于100kb的图片不压缩
                .synOrAsy(true)//同步true或异步false 压缩 默认同步
                .rotateEnabled(true) // 裁剪是否可旋转图片 true or false
                .scaleEnabled(true)// 裁剪是否可放大缩小图片 true or false
                .forResult(PictureConfig.CHOOSE_REQUEST);//结果回调onActivityResult code
    }

    private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
        @Override
        public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
            switch (requestCode) {
                case PictureConfig.CHOOSE_REQUEST:
                    List<LocalMedia> tmpSelectList = PictureSelector.obtainMultipleResult(data);
                    boolean isRecordSelected = cameraOptions.getBoolean("isRecordSelected");
                    if (!tmpSelectList.isEmpty() && isRecordSelected) {
                        selectList = tmpSelectList;
                    }

                    WritableArray imageList = new WritableNativeArray();
                    boolean enableBase64 = cameraOptions.getBoolean("enableBase64");

                    for (LocalMedia media : tmpSelectList) {
                        WritableMap aImage = new WritableNativeMap();

                        BitmapFactory.Options options = new BitmapFactory.Options();

                        options.inJustDecodeBounds = true;
                        if (!media.isCompressed()) {
                            BitmapFactory.decodeFile(media.getPath(), options);
                            aImage.putDouble("width", options.outWidth);
                            aImage.putDouble("height", options.outHeight);
                            aImage.putString("type", "image");
                            aImage.putString("uri", "file://" + media.getPath());

                            //decode to bitmap
                            Bitmap bitmap = BitmapFactory.decodeFile(media.getPath());
                            aImage.putInt("size", bitmap.getByteCount());

                            //base64 encode
                            if (enableBase64) {
                                String encodeString = getBase64EncodeString(bitmap);
                                aImage.putString("base64", encodeString);
                            }
                        } else {
                            // 压缩过，取 media.getCompressPath();
                            BitmapFactory.decodeFile(media.getCompressPath(), options);
                            aImage.putDouble("width", options.outWidth);
                            aImage.putDouble("height", options.outHeight);
                            aImage.putString("type", "image");
                            aImage.putString("uri", "file://" + media.getCompressPath());

                            //decode to bitmap
                            Bitmap bitmap = BitmapFactory.decodeFile(media.getCompressPath());
                            aImage.putInt("size", bitmap.getByteCount());

                            //base64 encode
                            if (enableBase64) {
                                String encodeString = getBase64EncodeString(bitmap);
                                aImage.putString("base64", encodeString);
                            }
                        }

                        if (media.isCut()) {
                            aImage.putString("original_uri", "file://" + media.getCutPath());
                        } else {
                            aImage.putString("original_uri", "file://" + media.getPath());
                        }

                        imageList.pushMap(aImage);
                    }
                    if (tmpSelectList.isEmpty()) {
                        invokeError();
                    } else {
                        invokeSuccessWithResult(imageList);
                    }
            }
        }
    };

    /**
     * 获取图片base64编码字符串
     * @param bitmap Bitmap对象
     * @return base64字符串
     */
    private String getBase64EncodeString(Bitmap bitmap) {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, baos);
        byte[] bytes = baos.toByteArray();

        byte[] encode = Base64.encode(bytes,Base64.DEFAULT);
        String encodeString = new String(encode);
        return "data:image/jpeg;base64," + encodeString;
    }

    /**
     * 选择照片成功时触发
     * @param imageList 图片数组
     */
    private void invokeSuccessWithResult(WritableArray imageList) {
        if (this.mPickerCallback != null) {
            this.mPickerCallback.invoke(null, imageList);
            this.mPickerCallback = null;
        } else if (this.mPickerPromise != null) {
            this.mPickerPromise.resolve(imageList);
        }
    }

    /**
     * 取消选择时触发
     */
    private void invokeError() {
        if (this.mPickerCallback != null) {
            this.mPickerCallback.invoke("取消");
            this.mPickerCallback = null;
        } else if (this.mPickerPromise != null) {
            this.mPickerPromise.reject(SY_SELECT_IMAGE_FAILED_CODE, "取消");
        }
    }
}
