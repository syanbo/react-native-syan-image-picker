package com.syanpicker

import android.provider.MediaStore
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.luck.picture.lib.basic.PictureSelector
import com.luck.picture.lib.config.SelectMimeType
import com.luck.picture.lib.config.SelectModeConfig
import com.luck.picture.lib.entity.LocalMedia
import com.luck.picture.lib.interfaces.OnResultCallbackListener
import com.syanpicker.engine.GlideImageEngine
import com.syanpicker.engine.ImageCompressEngine
import com.syanpicker.engine.SandboxEngine
import com.syanpicker.engine.UCropEngine
import android.os.SystemClock
import com.luck.picture.lib.basic.PictureCommonFragment
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

@ReactModule(name = RNSyanImagePickerModule.NAME)
class RNSyanImagePickerModule(
    reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    companion object {
        const val NAME = "RNSyanImagePicker"

        private const val GRID_SPAN_COUNT = 4

        /**
         * 与 PictureSelector 内部 `DoubleUtils` 的防重复点击窗口保持一致。
         *
         * 它的 `forResult()` 第一件事就是 `isFastDoubleClick()`，窗口内的调用会被
         * **静默丢弃** —— 而那时我们已经建好了 PendingRequest，promise 就永远挂住了。
         * 所以这里在启动之前先自己挡一道，把失败变成明确的 BUSY。
         */
        private const val LAUNCH_DEBOUNCE_MS = 600L

        /** 与 TS 侧 SY_PROGRESS_EVENT 必须一致。 */
        private const val PROGRESS_EVENT = "RNSyanImagePicker:progress"
    }

    /** 进度监听者计数。为 0 时一条事件也不发，不订阅的调用方零开销。 */
    private val progressListenerCount = AtomicInteger(0)

    /** 当前进行中的请求。同一时刻只允许一个选择器。 */
    private val activeRequest = AtomicReference<PendingRequest?>(null)

    private val lastLaunchAt = AtomicLong(0L)

    /**
     * 结果映射（解码、base64、封面抽帧）跑在这里。
     *
     * 老实现写的是 `new Thread(...).run()` —— `.run()` 是同步调用，线程压根没启动，
     * 于是所有解码和 base64 都堵在 UI 线程上。这里用真正的后台线程。
     *
     * 用守护线程是为了不覆写任何生命周期方法：`onCatalystInstanceDestroy` 在新版
     * RN 中已移除，而 `invalidate` 在 RN 0.67 上还不存在，覆写任何一个都会让某一端
     * 编译失败。守护线程不会阻止进程退出，因此不需要显式 shutdown。
     */
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "syan-image-picker").apply { isDaemon = true }
    }

    override fun getName(): String = NAME

    /* ---------------------------------------------------------------------- */
    /* 相册                                                                    */
    /* ---------------------------------------------------------------------- */

    @ReactMethod
    fun pickImage(options: ReadableMap?, promise: Promise) {
        val activity = requireActivity(promise) ?: return
        val request = ImageRequest.from(options)
        // 每次请求一个独立句柄，回调闭包独占持有，天然不会串到别的请求上。
        val pending = beginRequest(promise) ?: return

        PictureSelector.create(activity)
            .openGallery(SelectMimeType.ofImage())
            .setImageEngine(GlideImageEngine)
            .setSandboxFileEngine(SandboxEngine)
            .setSelectorUIStyle(
                SelectorStyle.build(request.wechatStyle, request.showSelectionIndex),
            )
            .setMaxSelectNum(request.maxCount)
            .setMinSelectNum(request.minCount)
            .setSelectionMode(
                if (request.maxCount > 1) SelectModeConfig.MULTIPLE
                else SelectModeConfig.SINGLE,
            )
            .setImageSpanCount(GRID_SPAN_COUNT)
            .setQuerySortOrder(sortOrder(request.sortAscending))
            .setFilterMaxFileSize(request.maxFileSize.toLong())
            .setSelectMinFileSize(request.minFileSize.toLong())
            .isDisplayCamera(request.showCameraButton)
            .isGif(request.allowGif)
            // 这三项 PictureSelector 默认就是 true，这里显式透传用户选择。
            // 与 isGif 一样，都是**查询层**过滤 —— 不满足的项根本不出现在列表里。
            .isWebp(request.allowWebp)
            .isBmp(request.allowBmp)
            .isHeic(request.allowHeic)
            .isOriginalControl(request.allowOriginal)
            .setSelectedData(toLocalMedia(request.selectedUris))
            .setPermissionDeniedListener { fragment, _, _, _ ->
                rejectPermission(pending, fragment)
            }
            .apply {
                if (request.compress.enabled) {
                    setCompressEngine(ImageCompressEngine(request.compress))
                }
                // 裁剪只在单选时有意义 —— 多选时 UCrop 的多图流程与本库的
                // 结果契约对不上，直接忽略，并已在类型注释中写明。
                if (request.crop.enabled && request.maxCount == 1) {
                    setCropEngine(UCropEngine(request.crop))
                }
            }
            .forResult(imageListener(pending, request.includeBase64, request.keepOriginal))
    }

    @ReactMethod
    fun pickVideo(options: ReadableMap?, promise: Promise) {
        val activity = requireActivity(promise) ?: return
        val request = VideoRequest.from(options)
        val pending = beginRequest(promise) ?: return

        PictureSelector.create(activity)
            .openGallery(SelectMimeType.ofVideo())
            .setImageEngine(GlideImageEngine)
            .setSandboxFileEngine(SandboxEngine)
            .setMaxSelectNum(request.maxCount)
            .setMinSelectNum(request.minCount)
            .setSelectionMode(
                if (request.maxCount > 1) SelectModeConfig.MULTIPLE
                else SelectModeConfig.SINGLE,
            )
            .setImageSpanCount(GRID_SPAN_COUNT)
            .setQuerySortOrder(sortOrder(request.sortAscending))
            .setFilterMaxFileSize(request.maxFileSize.toLong())
            .setSelectMinFileSize(request.minFileSize.toLong())
            .isDisplayCamera(request.showCameraButton)
            .setFilterVideoMaxSecond(request.maxDuration)
            .setFilterVideoMinSecond(request.minDuration)
            .setSelectedData(toLocalMedia(request.selectedUris))
            .setPermissionDeniedListener { fragment, _, _, _ ->
                rejectPermission(pending, fragment)
            }
            .forResult(videoListener(pending))
    }

    /* ---------------------------------------------------------------------- */
    /* 相机                                                                    */
    /* ---------------------------------------------------------------------- */

    @ReactMethod
    fun captureImage(options: ReadableMap?, promise: Promise) {
        val activity = requireActivity(promise) ?: return
        val request = CaptureImageRequest.from(options)
        val pending = beginRequest(promise) ?: return

        PictureSelector.create(activity)
            .openCamera(SelectMimeType.ofImage())
            .setSandboxFileEngine(SandboxEngine)
            .setPermissionDeniedListener { fragment, _, _, _ ->
                rejectPermission(pending, fragment)
            }
            .apply {
                if (request.compress.enabled) {
                    setCompressEngine(ImageCompressEngine(request.compress))
                }
                if (request.crop.enabled) {
                    setCropEngine(UCropEngine(request.crop))
                }
            }
            .forResult(imageListener(pending, request.includeBase64, request.keepOriginal))
    }

    @ReactMethod
    fun captureVideo(options: ReadableMap?, promise: Promise) {
        val activity = requireActivity(promise) ?: return
        val request = CaptureVideoRequest.from(options)
        val pending = beginRequest(promise) ?: return

        PictureSelector.create(activity)
            .openCamera(SelectMimeType.ofVideo())
            .setSandboxFileEngine(SandboxEngine)
            .setRecordVideoMaxSecond(request.recordDuration)
            .setPermissionDeniedListener { fragment, _, _, _ ->
                rejectPermission(pending, fragment)
            }
            .forResult(videoListener(pending))
    }

    /* ---------------------------------------------------------------------- */
    /* 预览                                                                    */
    /* ---------------------------------------------------------------------- */

    /**
     * 全屏预览一组本地文件。
     *
     * 纯展示，没有结果可返回；预览界面本身是另一个 Activity，关闭与否不影响
     * 本次调用 —— 因此启动成功就直接 resolve，不占用 [activeRequest] 那道闸。
     */
    @ReactMethod
    fun openPreview(options: ReadableMap?, promise: Promise) {
        val activity = requireActivity(promise) ?: return
        val request = PreviewRequest.from(options)

        if (request.uris.isEmpty()) {
            promise.resolve(null)
            return
        }

        val media = request.uris.mapNotNull { uri ->
            val path = uri.removePrefix("file://")
            runCatching {
                LocalMedia.generateLocalMedia(reactApplicationContext, path)
            }.getOrNull()
        }
        if (media.isEmpty()) {
            promise.reject(
                SyanErrorCode.EXPORT_FAILED.name,
                "没有可预览的有效文件",
            )
            return
        }

        PictureSelector.create(activity)
            .openPreview()
            .setImageEngine(GlideImageEngine)
            .isHidePreviewDownload(true)
            .startActivityPreview(
                request.index.coerceIn(0, media.size - 1),
                false, // 不显示删除按钮：本库不持有选中态，删除无从回传
                ArrayList(media),
            )

        promise.resolve(null)
    }

    /* ---------------------------------------------------------------------- */
    /* 进度事件                                                                */
    /* ---------------------------------------------------------------------- */

    /**
     * NativeEventEmitter 要求原生模块提供这两个桩方法 —— RN 0.67 上缺了会在
     * 控制台刷告警。它们只用来维护监听计数。
     */
    @ReactMethod
    fun addListener(eventName: String) {
        progressListenerCount.incrementAndGet()
    }

    @ReactMethod
    fun removeListeners(count: Double) {
        progressListenerCount.addAndGet(-count.toInt().coerceAtLeast(0))
            .coerceAtLeast(0)
            .let { progressListenerCount.set(it) }
    }

    private fun emitProgress(phase: String, completed: Int, total: Int) {
        if (progressListenerCount.get() <= 0) return

        val payload = Arguments.createMap().apply {
            putString("phase", phase)
            putInt("completed", completed)
            putInt("total", total)
        }
        runCatching {
            reactApplicationContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit(PROGRESS_EVENT, payload)
        }
    }

    /* ---------------------------------------------------------------------- */
    /* 缓存                                                                    */
    /* ---------------------------------------------------------------------- */

    @ReactMethod
    fun clearCache(promise: Promise) {
        worker.execute {
            runCatching { Cache.clear(reactApplicationContext) }
            promise.resolve(null)
        }
    }

    /* ---------------------------------------------------------------------- */
    /* 内部                                                                    */
    /* ---------------------------------------------------------------------- */

    /**
     * PictureSelector 需要 FragmentActivity。RN 的宿主 Activity 通常是
     * ReactActivity（继承自 AppCompatActivity），但 App 在后台或正在重建时
     * currentActivity 可能为 null —— 老实现在这里不判空，直接 NPE。
     */
    private fun requireActivity(promise: Promise): FragmentActivity? {
        // 走 ReactContext 而不是模块自身的 getCurrentActivity()：后者自 RN 0.80
        // 起已标记废弃。ReactContext.getCurrentActivity() 是一直存在的 Java 方法，
        // 从 RN 0.67 到最新版都可用，且不会触发废弃告警。
        val activity = reactApplicationContext.getCurrentActivity() as? FragmentActivity
        if (activity == null) {
            promise.reject(
                SyanErrorCode.NO_ACTIVITY.name,
                "当前没有可用的 Activity，无法打开选择器（App 可能处于后台）",
            )
        }
        return activity
    }

    /**
     * 开始一次请求。
     *
     * 两道闸：已有请求进行中、或距上次启动不足 [LAUNCH_DEBOUNCE_MS]，都直接
     * reject BUSY。后者是因为 PictureSelector 会静默吞掉窗口内的启动请求 ——
     * 不挡的话那个 promise 就永远挂着了。
     *
     * @return 可用的句柄；已被挡下时返回 null（此时 promise 已结算，调用方应直接 return）。
     */
    private fun beginRequest(promise: Promise): PendingRequest? {
        val now = SystemClock.elapsedRealtime()

        if (activeRequest.get() != null || now - lastLaunchAt.get() < LAUNCH_DEBOUNCE_MS) {
            promise.reject(
                SyanErrorCode.BUSY.name,
                "选择器正在使用中，或两次调用间隔过短（<${LAUNCH_DEBOUNCE_MS}ms）",
            )
            return null
        }

        val pending = PendingRequest(promise) { activeRequest.set(null) }
        if (!activeRequest.compareAndSet(null, pending)) {
            promise.reject(SyanErrorCode.BUSY.name, "选择器正在使用中")
            return null
        }

        lastLaunchAt.set(now)
        return pending
    }

    /**
     * 用户拒绝媒体或相机权限。
     *
     * 除了 reject，**还必须把选择器关掉**：装了自定义 denied 监听之后，
     * PictureSelector 就不再走自己那套"弹窗引导去设置"的默认流程，界面会一直
     * 停在那里 —— JS 已经收到 PERMISSION_DENIED，原生 UI 却还盖在 App 上。
     */
    private fun rejectPermission(pending: PendingRequest, fragment: Fragment?) {
        pending.reject(
            SyanErrorCode.PERMISSION_DENIED,
            "用户拒绝了所需的媒体或相机权限",
        )

        // forResult(listener) 起的是 PictureSelector 自己的 SupporterActivity，
        // 关掉它不会影响宿主 App 的 Activity。
        when (fragment) {
            is PictureCommonFragment -> fragment.onKeyBackFragmentFinish()
            else -> fragment?.activity?.finish()
        }
    }

    private fun sortOrder(ascending: Boolean): String =
        MediaStore.MediaColumns.DATE_MODIFIED + if (ascending) " ASC" else " DESC"

    /**
     * 由结果中的 assetId 还原选中项。
     *
     * assetId 是原始 MediaStore 资源标识（`content://` 或原始路径）；结果里的 uri
     * 指向的是压缩/裁剪产物，用它匹配不回相册条目。
     */
    private fun toLocalMedia(identifiers: List<String>): List<LocalMedia> =
        identifiers.mapNotNull { identifier ->
            val path = identifier.removePrefix("file://")
            runCatching {
                LocalMedia.generateLocalMedia(reactApplicationContext, path)
            }.getOrNull()
        }

    private fun imageListener(
        pending: PendingRequest,
        includeBase64: Boolean,
        keepOriginal: Boolean,
    ) =
        object : OnResultCallbackListener<LocalMedia> {
            override fun onResult(result: ArrayList<LocalMedia>?) {
                val media = result.orEmpty()
                if (media.isEmpty()) {
                    pending.cancel()
                    return
                }
                worker.execute {
                    try {
                        pending.resolve(
                            ResultMapper.mapImages(
                                reactApplicationContext,
                                media,
                                includeBase64,
                                keepOriginal,
                            ) { completed, total ->
                                emitProgress("processing", completed, total)
                            },
                        )
                    } catch (t: Throwable) {
                        pending.reject(
                            SyanErrorCode.EXPORT_FAILED,
                            t.message ?: "处理选中的图片失败",
                        )
                    }
                }
            }

            override fun onCancel() = pending.cancel()
        }

    private fun videoListener(pending: PendingRequest) =
        object : OnResultCallbackListener<LocalMedia> {
            override fun onResult(result: ArrayList<LocalMedia>?) {
                val media = result.orEmpty()
                if (media.isEmpty()) {
                    pending.cancel()
                    return
                }
                worker.execute {
                    try {
                        pending.resolve(
                            ResultMapper.mapVideos(reactApplicationContext, media) { done, total ->
                                emitProgress("exporting", done, total)
                            },
                        )
                    } catch (t: Throwable) {
                        pending.reject(
                            SyanErrorCode.EXPORT_FAILED,
                            t.message ?: "处理选中的视频失败",
                        )
                    }
                }
            }

            override fun onCancel() = pending.cancel()
        }
}
