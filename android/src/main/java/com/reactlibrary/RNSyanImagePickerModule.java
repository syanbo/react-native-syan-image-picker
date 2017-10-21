
package com.reactlibrary;

import android.app.Activity;
import android.content.Intent;
import android.graphics.BitmapFactory;

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
import com.luck.picture.lib.compress.Luban;
import com.luck.picture.lib.config.PictureConfig;
import com.luck.picture.lib.config.PictureMimeType;
import com.luck.picture.lib.entity.LocalMedia;

import java.util.ArrayList;
import java.util.List;

public class RNSyanImagePickerModule extends ReactContextBaseJavaModule {

    private static String SY_SELECT_IMAGE_FAILED_CODE = "0"; // 失败时，Promise用到的code

    private final ReactApplicationContext reactContext;

    private List<LocalMedia> selectList = new ArrayList<>();

    private Callback mPickerCallback; // 保存回调

    private Promise mPickerPromise; // 保存Promise

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
        this.mPickerPromise = null;
        this.mPickerCallback = callback;
        this.openImagePicker(options);
    }

    @ReactMethod
    public void asyncShowImagePicker(ReadableMap options, Promise promise) {
        this.mPickerCallback = null;
        this.mPickerPromise = promise;
        this.openImagePicker(options);
    }

    /**
     * 打开相册选择
     *
     * @param options 相册参数
     */
    private void openImagePicker(ReadableMap options) {
        int imageCount = options.getInt("imageCount");
        boolean isCamera = options.getBoolean("isCamera");
        boolean isCrop = options.getBoolean("isCrop");
        int CropW = options.getInt("CropW");
        int CropH = options.getInt("CropH");
        boolean isGif = options.getBoolean("isGif");
        boolean showCropCircle = options.getBoolean("showCropCircle");
        boolean showCropFrame = options.getBoolean("showCropFrame");
        boolean showCropGrid = options.getBoolean("showCropGrid");

        int modeValue;
        if (imageCount == 1) {
            modeValue = 1;
        } else {
            modeValue = 2;
        }
        Activity currentActivity = getCurrentActivity();
        PictureSelector.create(currentActivity)
                .openGallery(PictureMimeType.ofImage())// 全部.PictureMimeType.ofAll()、图片.ofImage()、视频.ofVideo()、音频.ofAudio()
                .maxSelectNum(imageCount)// 最大图片选择数量
                .minSelectNum(1)// 最小选择数量
                .imageSpanCount(4)// 每行显示个数
                .selectionMode(modeValue)// 多选 or 单选
                .previewImage(true)// 是否可预览图片
                .previewVideo(false)// 是否可预览视频
                .compressGrade(Luban.THIRD_GEAR)// luban压缩档次，默认3档 Luban.FIRST_GEAR、Luban.CUSTOM_GEAR
                .isCamera(isCamera)// 是否显示拍照按钮
                .enableCrop(isCrop)// 是否裁剪
                .compress(true)// 是否压缩
                .compressMode(PictureConfig.SYSTEM_COMPRESS_MODE)//系统自带 or 鲁班压缩 PictureConfig.SYSTEM_COMPRESS_MODE or LUBAN_COMPRESS_MODE
                .glideOverride(160, 160)// glide 加载宽高，越小图片列表越流畅，但会影响列表图片浏览的清晰度
                .withAspectRatio(CropW, CropH)// 裁剪比例 如16:9 3:2 3:4 1:1 可自定义 裁剪比例自定义
                .hideBottomControls(isCrop)// 是否显示uCrop工具栏，默认不显示
                .isGif(isGif)// 是否显示gif图片
                .freeStyleCropEnabled(true)// 裁剪框是否可拖拽
                .circleDimmedLayer(showCropCircle)// 是否圆形裁剪
                .showCropFrame(showCropFrame)// 是否显示裁剪矩形边框 圆形裁剪时建议设为false
                .showCropGrid(showCropGrid)// 是否显示裁剪矩形网格 圆形裁剪时建议设为false
                .openClickSound(false)// 是否开启点击声音
                .cropCompressQuality(90)// 裁剪压缩质量 默认100
                .scaleEnabled(true)// 裁剪是否可放大缩小图片
                .forResult(PictureConfig.CHOOSE_REQUEST);//结果回调onActivityResult code
    }

    private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
        @Override
        public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
            switch (requestCode) {
                case PictureConfig.CHOOSE_REQUEST:
                    selectList = PictureSelector.obtainMultipleResult(data);
                    WritableArray imageList = new WritableNativeArray();

                    for (LocalMedia media : selectList) {
                        WritableMap aImage = new WritableNativeMap();

                        BitmapFactory.Options options = new BitmapFactory.Options();
                        options.inJustDecodeBounds = true;
                        if (!media.isCompressed()) {
                            BitmapFactory.decodeFile(media.getPath(), options);
                            aImage.putDouble("width", options.outWidth);
                            aImage.putDouble("height", options.outHeight);
                            aImage.putString("type", "image");
                            aImage.putString("uri", "file://" + media.getPath());
                        } else {
                            // 压缩过，取 media.getCompressPath();
                            BitmapFactory.decodeFile(media.getCompressPath(), options);
                            aImage.putDouble("width", options.outWidth);
                            aImage.putDouble("height", options.outHeight);
                            aImage.putString("type", "image");
                            aImage.putString("uri", "file://" + media.getCompressPath());
                        }

                        if (media.isCut()) {
                            aImage.putString("original_uri", "file://" + media.getCutPath());
                        } else {
                            aImage.putString("original_uri", "file://" + media.getPath());
                        }

                        imageList.pushMap(aImage);
                    }
                    if (selectList.isEmpty()) {
                        invokeError();
                    } else {
                        invokeSuccessWithResult(imageList);
                    }
            }
        }
    };

    /**
     * 选择照片成功时触发
     *
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