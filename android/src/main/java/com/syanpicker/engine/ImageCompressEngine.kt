package com.syanpicker.engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import com.luck.picture.lib.engine.CompressFileEngine
import com.luck.picture.lib.interfaces.OnKeyValueResultCallbackListener
import com.syanpicker.Cache
import com.syanpicker.CompressConfig
import com.syanpicker.CompressMode
import com.syanpicker.CompressPlan
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * 图片压缩引擎。
 *
 * 自研而非沿用 Luban（`io.github.lucksiege:compress`），原因有三：
 *
 * 1. Luban 把质量**写死为 60**，且不接受尺寸上限 —— 手动模式根本没法用它实现。
 * 2. iOS 侧没有对应实现，要做到两端一致就必须自己掌握算法。
 * 3. 那套启发式本身只有二十来行算术（见 [CompressPlan]），外包给一个多年未更新
 *    的依赖并不划算。
 *
 * 自动模式跑 [CompressPlan.autoSampleSize]，与 iOS 的 `SYCompressPlan` 逐行对应。
 */
internal class ImageCompressEngine(
    private val config: CompressConfig,
) : CompressFileEngine {

    private companion object {
        /** 解码后再精确缩放的阈值：差距小于该比例就不值得多做一次 scale。 */
        const val EXACT_SCALE_EPSILON = 0.01
    }

    // PictureSelector 在主线程调用本方法，解码和编码必须挪走。
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "syan-compress").apply { isDaemon = true }
    }

    override fun onStartCompress(
        context: Context,
        source: ArrayList<Uri>,
        call: OnKeyValueResultCallbackListener?,
    ) {
        worker.execute {
            source.forEach { uri ->
                // 每一项都必须回调，少一次 PictureSelector 就会一直等下去。
                val result = runCatching { compress(context, uri) }.getOrNull()
                call?.onCallback(queueKeyOf(uri), result)
            }
        }
    }

    /**
     * 回传给 PictureSelector 的 key，**必须与它入队时用的字符串完全一致**。
     *
     * `PictureCommonFragment.onCompress` 是这样入队的：
     * ```
     * queue.put(media.availablePath, media)                       // key = 原始路径字符串
     * uris.add(isContent(path) ? Uri.parse(path) : Uri.fromFile(File(path)))
     * ```
     * 回调侧 `queue.get(key)`，且只有 `queue.size() == 0` 时才会继续走完流程。
     *
     * 所以对文件路径必须回传 `uri.path`（`/storage/...`）而不是 `uri.toString()`
     * （`file:///storage/...`）—— 后者匹配不上，队列永不排空，选择器会永远停在
     * loading，promise 也永不结算。参考实现 Luban 的 `getPath()` 正是
     * `isContent ? uri.toString() : uri.path`，替换 Luban 时漏掉了这一步。
     */
    private fun queueKeyOf(uri: Uri): String {
        val raw = uri.toString()
        return if (raw.startsWith("content://")) raw else uri.path ?: raw
    }

    private fun compress(context: Context, uri: Uri): String? {
        if (!config.enabled) return null

        /*
         GIF 一律原样放行。

         解码再编码只会拿到第一帧，动画就没了。之前用 Luban 时是靠它的
         `.filter { !path.endsWith(".gif") }` 挡住的，换成自研引擎后必须自己补上。
         iOS 侧走的是"原始字节"分支，同样不会重编码。
         */
        if (isGif(context, uri)) return null

        val sourceBytes = sizeOf(context, uri)
        // minSize 兜底：本来就很小的图再编码一次往往更大，直接放行。
        if (sourceBytes in 1 until config.minSize.toLong() * 1024L) {
            return null
        }

        val rawBounds = decodeBounds(context, uri) ?: return null
        val rotation = exifRotation(context, uri)

        /*
         按**摆正之后**的尺寸来算计划。

         decodeBounds 给的是存储尺寸（未应用 EXIF）。原来是先 fitInside 再旋转，
         对 EXIF 方向 6 的照片（存储 4032×3024、显示 3024×4032）配 maxHeight: 1000：
         fitInside 得 1333×1000，旋转后变成 1000×1333 —— 比调用方要的上限超了 33%，
         而 iOS 量的是已摆正的图，同一份输入两端结果不同。
         */
        val (srcWidth, srcHeight) = if (rotation == 90f || rotation == 270f) {
            rawBounds.second to rawBounds.first
        } else {
            rawBounds
        }

        val sampleSize: Int
        val target: Pair<Int, Int>?
        when (config.mode) {
            CompressMode.AUTO -> {
                sampleSize = CompressPlan.autoSampleSize(srcWidth, srcHeight)
                target = null // 自动模式只靠采样，不做二次精确缩放
            }

            CompressMode.MANUAL -> {
                val fitted =
                    CompressPlan.fitInside(srcWidth, srcHeight, config.maxWidth, config.maxHeight)
                // 先用 2 的幂粗降采样省内存，再精确缩放到目标尺寸。
                val rough = if (fitted.first > 0) srcWidth / fitted.first else 1
                sampleSize = CompressPlan.normalizeSampleSize(rough)
                target = fitted
            }

            CompressMode.NONE -> return null
        }

        var bitmap = decodeSampled(context, uri, sampleSize) ?: return null

        if (target != null) {
            val (tw, th) = target
            val delta = kotlin.math.abs(bitmap.width - tw).toDouble() / tw
            if (bitmap.width != tw && delta > EXACT_SCALE_EPSILON) {
                val scaled = Bitmap.createScaledBitmap(bitmap, tw, th, true)
                if (scaled != bitmap) {
                    bitmap.recycle()
                    bitmap = scaled
                }
            }
        }

        bitmap = rotateBitmap(bitmap, rotation)

        /*
         有 alpha 就自动保 PNG —— 与 iOS 同一判据。

         早先写的是 `config.keepAlpha && bitmap.hasAlpha()`，而 keepAlpha 默认 false，
         于是透明 PNG 用默认参数选进来会被编成 JPEG、透明区域变黑：那是内容被改了，
         不只是格式变了。现在 keepAlpha 退化为"强制输出 PNG"的逃生舱。

         双重判据：只有源格式本身支持 alpha 才可能有 alpha。我们用 ARGB_8888 解码，
         单看 `hasAlpha()` 有把不透明图也判成 PNG 的风险，体积会白白翻几倍。
         */
        val hasAlpha = sourceSupportsAlpha(context, uri) && bitmap.hasAlpha()
        val writePng = hasAlpha || config.keepAlpha
        val format = if (writePng) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG
        val extension = if (writePng) "png" else "jpg"

        val output = File(Cache.dir(context), "compress_${System.nanoTime()}.$extension")
        return try {
            FileOutputStream(output).use { out ->
                bitmap.compress(format, config.quality, out)
            }
            output.absolutePath.takeIf { output.length() > 0 }
        } catch (_: Throwable) {
            output.delete()
            null
        } finally {
            bitmap.recycle()
        }
    }

    /* ---------------------------------------------------------------------- */

    /** 源格式是否可能携带 alpha。JPEG 永远没有，判掉可以避免误判成 PNG。 */
    private fun sourceSupportsAlpha(context: Context, uri: Uri): Boolean {
        val mime = runCatching { context.contentResolver.getType(uri) }.getOrNull()
            ?: uri.toString().substringAfterLast('.', "").lowercase()
        return mime.contains("png") || mime.contains("webp")
    }

    /** 扩展名与 MIME 双重判断 —— content:// 路径上通常没有扩展名。 */
    private fun isGif(context: Context, uri: Uri): Boolean {
        val path = uri.toString().lowercase()
        if (path.substringBefore('?').endsWith(".gif")) return true

        val mime = runCatching { context.contentResolver.getType(uri) }.getOrNull()
        return mime?.equals("image/gif", ignoreCase = true) == true
    }

    private fun openStream(context: Context, uri: Uri): InputStream? = runCatching {
        if (uri.scheme == null || uri.scheme == "file") {
            File(uri.path ?: return null).inputStream()
        } else {
            context.contentResolver.openInputStream(uri)
        }
    }.getOrNull()

    private fun sizeOf(context: Context, uri: Uri): Long = runCatching {
        if (uri.scheme == null || uri.scheme == "file") {
            File(uri.path ?: "").length()
        } else {
            context.contentResolver.openAssetFileDescriptor(uri, "r")?.use { it.length } ?: -1L
        }
    }.getOrDefault(-1L)

    private fun decodeBounds(context: Context, uri: Uri): Pair<Int, Int>? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        openStream(context, uri)?.use { BitmapFactory.decodeStream(it, null, options) }
        return if (options.outWidth > 0 && options.outHeight > 0) {
            options.outWidth to options.outHeight
        } else {
            null
        }
    }

    private fun decodeSampled(context: Context, uri: Uri, sampleSize: Int): Bitmap? {
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize.coerceAtLeast(1)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return openStream(context, uri)?.use { BitmapFactory.decodeStream(it, null, options) }
    }

    /**
     * 读取 EXIF 方向对应的旋转角度。
     *
     * Luban 内部做了这件事，自研之后必须自己补上 —— 否则竖拍的照片压缩完会躺倒。
     */
    private fun exifRotation(context: Context, uri: Uri): Float =
        runCatching {
            openStream(context, uri)?.use { stream ->
                when (
                    ExifInterface(stream).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL,
                    )
                ) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
            } ?: 0f
        }.getOrDefault(0f)

    private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        if (degrees == 0f) return bitmap

        return runCatching {
            val matrix = Matrix().apply { postRotate(degrees) }
            val rotated = Bitmap.createBitmap(
                bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true,
            )
            if (rotated != bitmap) bitmap.recycle()
            rotated
        }.getOrDefault(bitmap)
    }
}
