package com.syanpicker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Base64
import android.util.Base64OutputStream
import androidx.exifinterface.media.ExifInterface
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.luck.picture.lib.entity.LocalMedia
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * LocalMedia → 跨桥结果。
 *
 * 全部在后台线程同步执行，因此**输出顺序天然与选择顺序一致** —— 老的 iOS 实现
 * 用多个异步回调往同一个数组里追加，顺序是乱的，这里从结构上就不会有那个问题。
 */
internal object ResultMapper {

    private const val COVER_JPEG_QUALITY = 80

    fun mapImages(
        context: Context,
        media: List<LocalMedia>,
        includeBase64: Boolean,
        keepOriginal: Boolean,
        onItemDone: ((completed: Int, total: Int) -> Unit)? = null,
    ): WritableArray {
        val array = Arguments.createArray()
        media.forEachIndexed { index, item ->
            array.pushMap(mapImage(context, item, includeBase64, keepOriginal))
            onItemDone?.invoke(index + 1, media.size)
        }
        return array
    }

    fun mapVideos(
        context: Context,
        media: List<LocalMedia>,
        onItemDone: ((completed: Int, total: Int) -> Unit)? = null,
    ): WritableArray {
        val array = Arguments.createArray()
        media.forEachIndexed { index, item ->
            array.pushMap(mapVideo(context, item))
            onItemDone?.invoke(index + 1, media.size)
        }
        return array
    }

    /* ---------------------------------------------------------------------- */

    private fun mapImage(
        context: Context,
        item: LocalMedia,
        includeBase64: Boolean,
        keepOriginal: Boolean,
    ): WritableMap {
        val path = resolveToFilePath(context, item.availablePath, item.mimeType)
            ?: throw IOException("无法解析图片路径：${item.availablePath}")
        val file = File(path)
        val (width, height) = decodeBounds(path, item.width, item.height)

        // originalUri 只在 keepOriginal 时给 —— 与 iOS 保持一致。
        // Android 这边拿它几乎不花钱（realPath 就是原图），但两端字段行为
        // 不一致会让调用方写出只在一个平台成立的代码，不值得。
        val originalPath = if (keepOriginal) {
            resolveToFilePath(
                context,
                item.realPath ?: item.originalPath ?: item.path,
                item.mimeType,
            )
        } else {
            null
        }

        return Arguments.createMap().apply {
            putString("uri", toFileUri(path))
            originalPath?.let { putString("originalUri", toFileUri(it)) }
            putInt("width", width)
            putInt("height", height)
            // 用 putDouble 而不是 (int)File.length()：老实现在这里会把超过 2GB 的
            // 长度截断，而且与视频路径的处理方式不一致。
            putDouble("size", file.length().toDouble())
            item.fileName?.takeIf { it.isNotEmpty() }?.let { putString("fileName", it) }
            putAssetId(item)

            if (includeBase64) {
                // 失败时**整个字段省略**，绝不返回半截数据编出来的"看起来合法"的串。
                encodeBase64(file)?.let { putString("base64", it) }
            }
        }
    }

    private fun mapVideo(context: Context, item: LocalMedia): WritableMap {
        val path = resolveToFilePath(context, item.availablePath, item.mimeType)
            ?: throw IOException("无法解析视频路径：${item.availablePath}")
        val file = File(path)
        val cover = extractCover(context, path)

        return Arguments.createMap().apply {
            putString("uri", toFileUri(path))
            putInt("width", if (item.width > 0) item.width else cover.width)
            putInt("height", if (item.height > 0) item.height else cover.height)
            putDouble("size", file.length().toDouble())
            putDouble("duration", item.duration.toDouble())
            putString("mime", item.mimeType?.takeIf { it.isNotEmpty() } ?: "video/mp4")
            putString("coverUri", cover.uri)
            item.fileName?.takeIf { it.isNotEmpty() }?.let { putString("fileName", it) }
            putAssetId(item)
        }
    }

    /**
     * 写入稳定的原始资源标识。
     *
     * [LocalMedia.getPath] 给的是相册里的原始项（Android 10+ 通常是 `content://`），
     * 而 `availablePath` 在压缩/裁剪之后会变成缓存文件路径。回填选中态必须用前者，
     * 否则 PictureSelector 匹配不到相册条目，已选项不会高亮。
     */
    private fun WritableMap.putAssetId(item: LocalMedia) {
        val identifier = item.path?.takeIf { it.isNotEmpty() }
            ?: item.realPath?.takeIf { it.isNotEmpty() }
            ?: item.id.takeIf { it > 0 }?.toString()
        if (identifier != null) {
            putString("assetId", identifier)
        }
    }

    /* ---------------------------------------------------------------------- */

    /**
     * 分区存储下 PictureSelector 可能给出 `content://` 形式的路径。已经配置了
     * SandboxFileEngine 的情况下通常拿到的就是沙箱内的真实路径，这里只是兜底。
     */
    private fun resolveToFilePath(
        context: Context,
        path: String?,
        mimeType: String?,
    ): String? {
        if (path.isNullOrEmpty()) return null
        if (!path.startsWith("content://")) return path
        // 与 SandboxEngine 共用同一份实现，产物落在受管理的缓存目录下。
        return Cache.copyIntoCache(context, path, mimeType)
    }

    private fun toFileUri(path: String): String =
        if (path.startsWith("file://")) path else Uri.fromFile(File(path)).toString()

    /**
     * 从最终文件解码真实尺寸。裁剪或压缩之后，LocalMedia 上带的宽高可能是处理前的。
     */
    private fun decodeBounds(
        path: String,
        fallbackWidth: Int,
        fallbackHeight: Int,
    ): Pair<Int, Int> = try {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)
        if (options.outWidth > 0 && options.outHeight > 0) {
            val orientation = runCatching {
                ExifInterface(path).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
            CompressPlan.uprightSize(options.outWidth, options.outHeight, orientation)
        } else {
            fallbackWidth to fallbackHeight
        }
    } catch (_: Throwable) {
        fallbackWidth to fallbackHeight
    }

    /**
     * 流式 base64。
     *
     * 老实现把整个文件读进 ByteArrayOutputStream、不关流，而且吞掉 IOException 之后
     * 依然返回一个格式合法的字符串 —— 调用方拿到的是静默损坏的数据。这里失败一律
     * 返回 null，由调用方省略该字段。
     */
    private fun encodeBase64(file: File): String? = try {
        ByteArrayOutputStream().use { sink ->
            Base64OutputStream(sink, Base64.NO_WRAP).use { encoder ->
                file.inputStream().use { input -> input.copyTo(encoder) }
            }
            sink.toString(Charsets.US_ASCII.name())
        }
    } catch (_: IOException) {
        null
    } catch (_: OutOfMemoryError) {
        // 超大图 + base64 是最经典的 OOM 组合。宁可不返回该字段，也不要拖垮宿主 App。
        null
    }

    private data class Cover(val uri: String, val width: Int, val height: Int)

    private fun extractCover(context: Context, videoPath: String): Cover {
        val retriever = MediaMetadataRetriever()
        var frame: Bitmap? = null
        try {
            retriever.setDataSource(videoPath)
            frame = retriever.frameAtTime ?: return Cover("", 0, 0)

            val target = File(Cache.dir(context), "cover_${System.nanoTime()}.jpg")
            FileOutputStream(target).use { out ->
                frame.compress(Bitmap.CompressFormat.JPEG, COVER_JPEG_QUALITY, out)
            }
            return Cover(toFileUri(target.absolutePath), frame.width, frame.height)
        } catch (_: Throwable) {
            return Cover("", 0, 0)
        } finally {
            // 老实现只在成功路径上 release，异常路径每次都泄漏一个 native retriever。
            frame?.recycle()
            runCatching { retriever.release() }
        }
    }
}
