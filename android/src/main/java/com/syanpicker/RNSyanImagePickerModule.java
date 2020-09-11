
package com.syanpicker;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.text.TextUtils;
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
import com.luck.picture.lib.tools.SdkVersionUtils;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

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

    @ReactMethod
    public void asyncOpenCamera(ReadableMap options, Promise promise) {
        this.cameraOptions = options;
        this.mPickerCallback = null;
        this.mPickerPromise = promise;
        this.openCamera();
    }

    /**
     * 缓存清除
     * 包括裁剪和压缩后的缓存，要在上传成功后调用，注意：需要系统sd卡权限
     */
    @ReactMethod
    public void deleteCache() {
        Activity currentActivity = getCurrentActivity();
        PictureFileUtils.deleteAllCacheDirFile(currentActivity);
    }

    /**
     * 移除选中的图片
     * index 要移除的图片下标
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

    @ReactMethod
    public void openVideo(ReadableMap options, Callback callback) {
        this.cameraOptions = options;
        this.mPickerPromise = null;
        this.mPickerCallback = callback;
        this.openVideo();
    }

    @ReactMethod
    public void openVideoPicker(ReadableMap options, Callback callback) {
        this.cameraOptions = options;
        this.mPickerPromise = null;
        this.mPickerCallback = callback;
        this.openVideoPicker();
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
        boolean compress = this.cameraOptions.getBoolean("compress");
        boolean freeStyleCropEnabled = this.cameraOptions.getBoolean("freeStyleCropEnabled");
        boolean rotateEnabled = this.cameraOptions.getBoolean("rotateEnabled");
        boolean scaleEnabled = this.cameraOptions.getBoolean("scaleEnabled");
        int minimumCompressSize = this.cameraOptions.getInt("minimumCompressSize");
        int quality = this.cameraOptions.getInt("quality");
        boolean isWeChatStyle = this.cameraOptions.getBoolean("isWeChatStyle");
        boolean showSelectedIndex = this.cameraOptions.getBoolean("showSelectedIndex");

        int modeValue;
        if (imageCount == 1) {
            modeValue = 1;
        } else {
            modeValue = 2;
        }

        Boolean isAndroidQ = SdkVersionUtils.checkedAndroid_Q();

        Activity currentActivity = getCurrentActivity();
        PictureSelector.create(currentActivity)
                .openGallery(PictureMimeType.ofImage())//全部.PictureMimeType.ofAll()、图片.ofImage()、视频.ofVideo()、音频.ofAudio()
                .loadImageEngine(GlideEngine.createGlideEngine())
                .maxSelectNum(imageCount)// 最大图片选择数量 int
                .minSelectNum(0)// 最小选择数量 int
                .imageSpanCount(4)// 每行显示个数 int
                .selectionMode(modeValue)// 多选 or 单选 PictureConfig.MULTIPLE or PictureConfig.SINGLE
                .previewImage(true)// 是否可预览图片 true or false
                .previewVideo(false)// 是否可预览视频 true or false
                .enablePreviewAudio(false) // 是否可播放音频 true or false
                .isCamera(isCamera)// 是否显示拍照按钮 true or false
                .imageFormat(isAndroidQ ? PictureMimeType.PNG_Q : PictureMimeType.PNG)// 拍照保存图片格式后缀,默认jpeg
                .isZoomAnim(true)// 图片列表点击 缩放效果 默认true
                .sizeMultiplier(0.5f)// glide 加载图片大小 0~1之间 如设置 .glideOverride()无效
                .enableCrop(isCrop)// 是否裁剪 true or false
                .compress(compress)// 是否压缩 true or false
                .glideOverride(160, 160)// int glide 加载宽高，越小图片列表越流畅，但会影响列表图片浏览的清晰度
                .withAspectRatio(CropW, CropH)// int 裁剪比例 如16:9 3:2 3:4 1:1 可自定义
                .hideBottomControls(isCrop)// 是否显示uCrop工具栏，默认不显示 true or false
                .isGif(isGif)// 是否显示gif图片 true or false
                .freeStyleCropEnabled(freeStyleCropEnabled)// 裁剪框是否可拖拽 true or false
                .circleDimmedLayer(showCropCircle)// 是否圆形裁剪 true or false
                .showCropFrame(showCropFrame)// 是否显示裁剪矩形边框 圆形裁剪时建议设为false   true or false
                .showCropGrid(showCropGrid)// 是否显示裁剪矩形网格 圆形裁剪时建议设为false    true or false
                .openClickSound(false)// 是否开启点击声音 true or false
                .cropCompressQuality(quality)// 裁剪压缩质量 默认90 int
                .minimumCompressSize(minimumCompressSize)// 小于100kb的图片不压缩
                .synOrAsy(true)//同步true或异步false 压缩 默认同步
                .rotateEnabled(rotateEnabled) // 裁剪是否可旋转图片 true or false
                .scaleEnabled(scaleEnabled)// 裁剪是否可放大缩小图片 true or false
                .selectionMedia(selectList) // 当前已选中的图片 List
                .isWeChatStyle(isWeChatStyle)
                .theme(showSelectedIndex ? R.style.picture_WeChat_style : 0)
                .forResult(PictureConfig.CHOOSE_REQUEST); //结果回调onActivityResult code
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
        boolean compress = this.cameraOptions.getBoolean("compress");
        boolean freeStyleCropEnabled = this.cameraOptions.getBoolean("freeStyleCropEnabled");
        boolean rotateEnabled = this.cameraOptions.getBoolean("rotateEnabled");
        boolean scaleEnabled = this.cameraOptions.getBoolean("scaleEnabled");
        int minimumCompressSize = this.cameraOptions.getInt("minimumCompressSize");
        int quality = this.cameraOptions.getInt("quality");
        boolean isWeChatStyle = this.cameraOptions.getBoolean("isWeChatStyle");
        boolean showSelectedIndex = this.cameraOptions.getBoolean("showSelectedIndex");

        Boolean isAndroidQ = SdkVersionUtils.checkedAndroid_Q();

        Activity currentActivity = getCurrentActivity();
        PictureSelector.create(currentActivity)
                .openCamera(PictureMimeType.ofImage())
                .loadImageEngine(GlideEngine.createGlideEngine())
                .imageFormat(isAndroidQ ? PictureMimeType.PNG_Q : PictureMimeType.PNG)// 拍照保存图片格式后缀,默认jpeg
                .enableCrop(isCrop)// 是否裁剪 true or false
                .compress(compress)// 是否压缩 true or false
                .glideOverride(160, 160)// int glide 加载宽高，越小图片列表越流畅，但会影响列表图片浏览的清晰度
                .withAspectRatio(CropW, CropH)// int 裁剪比例 如16:9 3:2 3:4 1:1 可自定义
                .hideBottomControls(isCrop)// 是否显示uCrop工具栏，默认不显示 true or false
                .freeStyleCropEnabled(freeStyleCropEnabled)// 裁剪框是否可拖拽 true or false
                .circleDimmedLayer(showCropCircle)// 是否圆形裁剪 true or false
                .showCropFrame(showCropFrame)// 是否显示裁剪矩形边框 圆形裁剪时建议设为false   true or false
                .showCropGrid(showCropGrid)// 是否显示裁剪矩形网格 圆形裁剪时建议设为false    true or false
                .openClickSound(false)// 是否开启点击声音 true or false
                .cropCompressQuality(quality)// 裁剪压缩质量 默认90 int
                .minimumCompressSize(minimumCompressSize)// 小于100kb的图片不压缩
                .synOrAsy(true)//同步true或异步false 压缩 默认同步
                .rotateEnabled(rotateEnabled) // 裁剪是否可旋转图片 true or false
                .scaleEnabled(scaleEnabled)// 裁剪是否可放大缩小图片 true or false
                .isWeChatStyle(isWeChatStyle)
                .theme(showSelectedIndex ? R.style.picture_WeChat_style : 0)
                .forResult(PictureConfig.CHOOSE_REQUEST);//结果回调onActivityResult code
    }

    /**
     * 拍摄视频
     */
    private void openVideo() {
        int quality = this.cameraOptions.getInt("quality");
        int MaxSecond = this.cameraOptions.getInt("MaxSecond");
        int MinSecond = this.cameraOptions.getInt("MinSecond");
        int recordVideoSecond = this.cameraOptions.getInt("recordVideoSecond");
        int imageCount = this.cameraOptions.getInt("imageCount");
        Activity currentActivity = getCurrentActivity();
        PictureSelector.create(currentActivity)
                .openCamera(PictureMimeType.ofVideo())//全部.PictureMimeType.ofAll()、图片.ofImage()、视频.ofVideo()、音频.ofAudio()
                .loadImageEngine(GlideEngine.createGlideEngine())
                .selectionMedia(selectList) // 当前已选中的图片 List
                .openClickSound(false)// 是否开启点击声音 true or false
                .maxSelectNum(imageCount)// 最大图片选择数量 int
                .minSelectNum(0)// 最小选择数量 int
                .imageSpanCount(4)// 每行显示个数 int
                .selectionMode(PictureConfig.MULTIPLE)// 多选 or 单选 PictureConfig.MULTIPLE or PictureConfig.SINGLE
                .previewVideo(true)// 是否可预览视频 true or false
                .videoQuality(quality)// 视频录制质量 0 or 1 int
                .videoMaxSecond(MaxSecond)// 显示多少秒以内的视频or音频也可适用 int
                .videoMinSecond(MinSecond)// 显示多少秒以内的视频or音频也可适用 int
                .recordVideoSecond(recordVideoSecond)//视频秒数录制 默认60s int
                .forResult(PictureConfig.REQUEST_CAMERA);//结果回调onActivityResult code
    }

    /**
     * 选择视频
     */
    private void openVideoPicker() {
        int quality = this.cameraOptions.getInt("quality");
        int MaxSecond = this.cameraOptions.getInt("MaxSecond");
        int MinSecond = this.cameraOptions.getInt("MinSecond");
        int recordVideoSecond = this.cameraOptions.getInt("recordVideoSecond");
        int videoCount = this.cameraOptions.getInt("imageCount");
        boolean isCamera = this.cameraOptions.getBoolean("allowTakeVideo");

        Activity currentActivity = getCurrentActivity();
        PictureSelector.create(currentActivity)
                .openGallery(PictureMimeType.ofVideo())//全部.PictureMimeType.ofAll()、图片.ofImage()、视频.ofVideo()、音频.ofAudio()
                .loadImageEngine(GlideEngine.createGlideEngine())
                .selectionMedia(selectList) // 当前已选中的视频 List
                .openClickSound(false)// 是否开启点击声音 true or false
                .isCamera(isCamera)// 是否显示拍照按钮 true or false
                .maxSelectNum(videoCount)// 最大视频选择数量 int
                .minSelectNum(1)// 最小选择数量 int
                .imageSpanCount(4)// 每行显示个数 int
                .selectionMode(PictureConfig.MULTIPLE)// 多选 or 单选 PictureConfig.MULTIPLE or PictureConfig.SINGLE
                .previewVideo(true)// 是否可预览视频 true or false
                .videoQuality(quality)// 视频录制质量 0 or 1 int
                .videoMaxSecond(MaxSecond)// 显示多少秒以内的视频or音频也可适用 int
                .videoMinSecond(MinSecond)// 显示多少秒以内的视频or音频也可适用 int
                .recordVideoSecond(recordVideoSecond)//视频秒数录制 默认60s int
                .forResult(PictureConfig.REQUEST_CAMERA);//结果回调onActivityResult code
    }

    private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
        @Override
        public void onActivityResult(Activity activity, int requestCode, int resultCode, final Intent data) {
            if (resultCode == -1) {
                if (requestCode == PictureConfig.CHOOSE_REQUEST) {
                    new Thread(new Runnable() {
                        @Override
                        public void run() {
                            onGetResult(data);
                        }
                    }).run();
                } else if (requestCode == PictureConfig.REQUEST_CAMERA) {
                    onGetVideoResult(data);
                }
            } else {
                invokeError(resultCode);
            }

        }
    };

    private void onGetVideoResult(Intent data) {
        List<LocalMedia> mVideoSelectList = PictureSelector.obtainMultipleResult(data);
        boolean isRecordSelected = cameraOptions.getBoolean("isRecordSelected");
        if (!mVideoSelectList.isEmpty() && isRecordSelected) {
            selectList = mVideoSelectList;
        }
        WritableArray videoList = new WritableNativeArray();

        for (LocalMedia media : mVideoSelectList) {
            if (TextUtils.isEmpty(media.getPath())) {
                continue;
            }

            WritableMap videoMap = new WritableNativeMap();

            Boolean isAndroidQ = SdkVersionUtils.checkedAndroid_Q();
            String filePath = isAndroidQ ? media.getAndroidQToPath() : media.getPath();

            videoMap.putString("uri", "file://" + filePath);
            videoMap.putString("coverUri", "file://" + this.getVideoCover(filePath));
            videoMap.putString("fileName", new File(media.getPath()).getName());
            videoMap.putDouble("size", new File(media.getPath()).length());
            videoMap.putDouble("duration", media.getDuration() / 1000.00);
            videoMap.putInt("width", media.getWidth());
            videoMap.putInt("height", media.getHeight());
            videoMap.putString("type", "video");
            videoMap.putString("mime", media.getMimeType());
            videoList.pushMap(videoMap);
        }

        invokeSuccessWithResult(videoList);
    }

    private void onGetResult(Intent data) {
        List<LocalMedia> tmpSelectList = PictureSelector.obtainMultipleResult(data);
        boolean isRecordSelected = cameraOptions.getBoolean("isRecordSelected");
        if (!tmpSelectList.isEmpty() && isRecordSelected) {
            selectList = tmpSelectList;
        }

        WritableArray imageList = new WritableNativeArray();
        boolean enableBase64 = cameraOptions.getBoolean("enableBase64");

        for (LocalMedia media : tmpSelectList) {
            imageList.pushMap(getImageResult(media, enableBase64));
        }
        invokeSuccessWithResult(imageList);
    }

    private WritableMap getImageResult(LocalMedia media, Boolean enableBase64) {
        WritableMap imageMap = new WritableNativeMap();
        String path = media.getPath();

        if (media.isCompressed() || media.isCut()) {
            path = media.getCompressPath();
        }

        if (media.isCut()) {
            path = media.getCutPath();
        }

        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(path, options);
        imageMap.putDouble("width", options.outWidth);
        imageMap.putDouble("height", options.outHeight);
        imageMap.putString("type", "image");
        imageMap.putString("uri", "file://" + path);
        imageMap.putString("original_uri", "file://" + media.getPath());
        imageMap.putInt("size", (int) new File(path).length());

        if (enableBase64) {
            String encodeString = getBase64StringFromFile(path);
            imageMap.putString("base64", encodeString);
        }

        return imageMap;
    }

    /**
     * 获取图片base64编码字符串
     *
     * @param absoluteFilePath 文件路径
     * @return base64字符串
     */
    private String getBase64StringFromFile(String absoluteFilePath) {
        InputStream inputStream;
        try {
            inputStream = new FileInputStream(new File(absoluteFilePath));
        } catch (FileNotFoundException e) {
            e.printStackTrace();
            return null;
        }

        byte[] bytes;
        byte[] buffer = new byte[8192];
        int bytesRead;
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        try {
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                output.write(buffer, 0, bytesRead);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        bytes = output.toByteArray();
        return "data:image/jpeg;base64," + Base64.encodeToString(bytes, Base64.NO_WRAP);
    }


    /**
     * 获取视频封面图片
     * @param videoPath 视频地址
     */
    private String getVideoCover(String videoPath) {
        try {
            MediaMetadataRetriever retriever = new MediaMetadataRetriever();
            retriever.setDataSource(videoPath);
            Bitmap bitmap = retriever.getFrameAtTime();
            FileOutputStream outStream = null;
            final String uuid = "thumb-" + UUID.randomUUID().toString();
            final String localThumb = reactContext.getExternalCacheDir().getAbsolutePath() + "/" + uuid + ".jpg";
            outStream = new FileOutputStream(new File(localThumb));
            bitmap.compress(Bitmap.CompressFormat.JPEG, 30, outStream);
            outStream.close();
            retriever.release();

            return localThumb;
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } catch (Exception err) {
            err.printStackTrace();
        }

        return null;
    }

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
    private void invokeError(int resultCode) {
        String message = "取消";
        if (resultCode != 0) {
            message = String.valueOf(resultCode);
        }
        if (this.mPickerCallback != null) {
            this.mPickerCallback.invoke(message);
            this.mPickerCallback = null;
        } else if (this.mPickerPromise != null) {
            this.mPickerPromise.reject(SY_SELECT_IMAGE_FAILED_CODE, message);
        }
    }
}
