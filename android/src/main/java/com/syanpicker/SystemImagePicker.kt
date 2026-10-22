package com.syanpicker

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.BaseActivityEventListener
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil
import com.luck.picture.lib.entity.LocalMedia
import com.syanpicker.engine.ImageCompressEngine
import com.syanpicker.engine.UCropEngine
import com.yalantis.ucrop.UCrop
import java.io.File
import java.util.concurrent.Executor

/**
 * 系统 Photo Picker（`PICK_IMAGES`）分支。
 *
 * 选完后：复制进缓存 → 按选项剔除 → 单选裁剪（UCrop）→ 压缩 → [ResultMapper]，
 * 与 PictureSelector 分支共用裁剪、压缩和结果映射。
 *
 * 结果经 RN 的 ActivityEventListener 回来，不依赖 androidx.activity 的 Result API：
 * 后者的 PickVisualMedia 要 activity 1.6+ 和 compileSdk 33。
 */
internal class SystemImagePicker(
    private val context: ReactApplicationContext,
    private val worker: Executor,
    private val onProgress: (completed: Int, total: Int) -> Unit,
) : BaseActivityEventListener() {

    private companion object {
        /** 取 16 位以内，FragmentActivity 不接受更大的 requestCode。 */
        const val REQUEST_PICK = 0x5301
        const val REQUEST_CROP = 0x5302
    }

    /** 一次请求的中间状态。LaunchGate 保证同一时刻最多一个。 */
    private class Session(
        val pending: PendingRequest,
        val request: ImageRequest,
    ) {
        /** 裁剪前的那张图，裁剪结果回来后接着用。 */
        var cropSource: PickedImage? = null
    }

    /** [sourceUri] 是系统 Picker 给的 URI，作为结果的 assetId。 */
    private class PickedImage(
        val sourceUri: String,
        val file: PickedFile,
        val fileName: String?,
        var finalPath: String = file.path,
    )

    @Volatile
    private var session: Session? = null

    init {
        context.addActivityEventListener(this)
    }

    /** 按门槛、可用性和 Intent 可解析性决定这次是否走系统 Picker。 */
    fun shouldUse(activity: Activity, request: ImageRequest): Boolean {
        val sdk = Build.VERSION.SDK_INT
        val minSdk = SystemPickerPolicy.resolveMinSdk(manifestMinSdk(), request.systemPickerMinSdk)
        // 先比门槛：没到门槛就不去查扩展版本和 Intent。
        if (sdk < minSdk) return false
        val available = SystemPickerPolicy.isAvailable(sdk, rExtensionVersion())
        val resolvable = available &&
            buildIntent(request.maxCount).resolveActivity(activity.packageManager) != null
        return SystemPickerPolicy.shouldUse(sdk, minSdk, available, resolvable)
    }

    /**
     * 打开系统 Picker。
     *
     * @return false 表示没能打开（Intent 解析后仍找不到 Activity），调用方改走 PictureSelector
     */
    fun launch(activity: Activity, request: ImageRequest, pending: PendingRequest): Boolean {
        val current = Session(pending, request)
        session = current
        return try {
            activity.startActivityForResult(buildIntent(request.maxCount), REQUEST_PICK)
            true
        } catch (t: Throwable) {
            clear(current)
            if (t is ActivityNotFoundException) false else throw t
        }
    }

    override fun onActivityResult(activity: Activity, requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK && requestCode != REQUEST_CROP) return
        val current = session ?: return
        when (requestCode) {
            REQUEST_PICK -> onPicked(current, resultCode, data)
            REQUEST_CROP -> onCropped(current, resultCode, data)
        }
    }

    /* ---------------------------------------------------------------------- */

    private fun onPicked(current: Session, resultCode: Int, data: Intent?) {
        val uris = if (resultCode == Activity.RESULT_OK && data != null) {
            val clip = data.clipData
            val clipUris = if (clip == null) {
                emptyList()
            } else {
                (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri?.toString() }
            }
            SystemPickerPolicy.collectUris(data.data?.toString(), clipUris, current.request.maxCount)
        } else {
            emptyList()
        }
        if (uris.isEmpty()) {
            settle(current) { it.pending.cancel() }
            return
        }

        // 临时授权只在这次结果里有效，必须马上复制，不能等到裁剪或压缩时再读。
        worker.execute {
            runStep(current, "处理选中的图片失败") {
                val images = copyAndFilter(current, uris) ?: return@runStep
                val crop = current.request.crop
                if (crop.enabled && current.request.maxCount == 1 && images.size == 1) {
                    current.cropSource = images[0]
                    UiThreadUtil.runOnUiThread { startCrop(current, images[0]) }
                } else {
                    finish(current, images)
                }
            }
        }
    }

    /** 复制失败时已 reject EXPORT_FAILED 并返回 null。 */
    private fun copyAndFilter(current: Session, uris: List<String>): List<PickedImage>? {
        val resolver = context.contentResolver
        val mimes = uris.associateWith { uri ->
            runCatching { resolver.getType(Uri.parse(uri)) }.getOrNull()
        }
        val outcome = SystemPickerPolicy.copyAll(
            uris,
            copy = { uri -> Cache.copyIntoCache(context, uri, mimes[uri]) },
            discard = { path -> File(path).delete() },
        )
        val copied = when (outcome) {
            is CopyOutcome.Copied -> outcome.paths
            is CopyOutcome.Failed -> {
                settle(current) { it.pending.reject(outcome.code, "无法读取选中的图片：${outcome.source}") }
                return null
            }
        }

        val filter = PickFilter.from(current.request)
        val kept = ArrayList<PickedImage>(uris.size)
        uris.zip(copied).forEach { (uri, path) ->
            val file = PickedFile(path, mimes[uri], File(path).length())
            if (SystemPickerPolicy.accepts(file, filter)) {
                kept += PickedImage(uri, file, displayName(uri))
            } else {
                File(path).delete()
            }
        }
        return kept
    }

    private fun startCrop(current: Session, image: PickedImage) {
        val activity = context.getCurrentActivity()
        if (activity == null) {
            settle(current) {
                it.pending.reject(SyanErrorCode.NO_ACTIVITY, "当前没有可用的 Activity，无法打开裁剪")
            }
            return
        }
        try {
            val source = Uri.fromFile(File(image.file.path))
            val destination = Uri.fromFile(File(Cache.dir(context), "crop_${System.nanoTime()}.jpg"))
            UCropEngine(current.request.crop)
                .build(activity, source, destination, arrayListOf(source.toString()))
                .start(activity, REQUEST_CROP)
        } catch (t: Throwable) {
            settle(current) {
                it.pending.reject(SyanErrorCode.EXPORT_FAILED, t.message ?: "无法打开裁剪")
            }
        }
    }

    private fun onCropped(current: Session, resultCode: Int, data: Intent?) {
        val image = current.cropSource ?: return
        when (resultCode) {
            Activity.RESULT_OK -> {
                val output = data?.let { UCrop.getOutput(it) }?.path
                if (output == null) {
                    settle(current) { it.pending.reject(SyanErrorCode.EXPORT_FAILED, "裁剪没有产出文件") }
                    return
                }
                image.finalPath = output
                worker.execute { runStep(current, "处理裁剪结果失败") { finish(current, listOf(image)) } }
            }
            UCrop.RESULT_ERROR -> settle(current) {
                val message = data?.let { UCrop.getError(it)?.message } ?: "裁剪失败"
                it.pending.reject(SyanErrorCode.EXPORT_FAILED, message)
            }
            // 裁剪页返回：系统 Picker 已经关了，回不到网格，按取消处理。
            else -> settle(current) { it.pending.cancel() }
        }
    }

    /** 压缩并映射结果。在 [worker] 上调用。 */
    private fun finish(current: Session, images: List<PickedImage>) {
        val request = current.request
        if (request.compress.enabled) {
            val engine = ImageCompressEngine(request.compress)
            images.forEach { image ->
                engine.compressFile(context, image.finalPath)?.let { image.finalPath = it }
            }
        }
        val media = images.map { image ->
            LocalMedia().apply {
                path = image.sourceUri
                // keepOriginal 时 ResultMapper 取 realPath 作为 originalUri。
                realPath = image.file.path
                sandboxPath = image.finalPath
                mimeType = image.file.mimeType
                fileName = image.fileName
            }
        }
        val assets = if (media.isEmpty()) {
            Arguments.createArray()
        } else {
            ResultMapper.mapImages(context, media, request.includeBase64, request.keepOriginal, onProgress)
        }
        settle(current) { it.pending.resolve(assets) }
    }

    /* ---------------------------------------------------------------------- */

    private fun runStep(current: Session, fallbackMessage: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            settle(current) { it.pending.reject(SyanErrorCode.EXPORT_FAILED, t.message ?: fallbackMessage) }
        }
    }

    private inline fun settle(current: Session, action: (Session) -> Unit) {
        clear(current)
        action(current)
    }

    private fun clear(current: Session) {
        if (session === current) session = null
    }

    private fun buildIntent(maxCount: Int): Intent =
        Intent(SystemPickerPolicy.ACTION_PICK_IMAGES).apply {
            type = "image/*"
            SystemPickerPolicy.maxExtra(maxCount)?.let {
                putExtra(SystemPickerPolicy.EXTRA_PICK_IMAGES_MAX, it)
            }
        }

    @Suppress("DEPRECATION")
    private fun manifestMinSdk(): Int? = runCatching {
        val info = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        SystemPickerPolicy.parseMetaValue(info.metaData?.get(SystemPickerPolicy.META_MIN_SDK))
    }.getOrNull()

    /** 反射调用：SdkExtensions 在 compileSdk 33 之前的 android.jar 里没有公开。 */
    private fun rExtensionVersion(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return 0
        return runCatching {
            Class.forName("android.os.ext.SdkExtensions")
                .getMethod("getExtensionVersion", Int::class.javaPrimitiveType)
                .invoke(null, Build.VERSION_CODES.R) as Int
        }.getOrDefault(0)
    }

    private fun displayName(uri: String): String? = runCatching {
        context.contentResolver.query(
            Uri.parse(uri),
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }.getOrNull()
}
