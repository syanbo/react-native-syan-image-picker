package com.syanpicker

import android.content.Context
import android.net.Uri
import java.io.File

/**
 * 本库产生的中间文件（沙箱副本、压缩产物、裁剪产物、视频封面）统一放在这个目录下，
 * 这样 [clear] 才能只删自己的东西，不会误伤宿主 App 的缓存。
 */
internal object Cache {

    private const val DIR_NAME = "syan-image-picker"

    /**
     * externalCacheDir 在外置存储不可用时会返回 null —— 老实现直接解引用，
     * 于是在没有外置存储的设备上必崩。这里退回到内部缓存目录。
     */
    fun dir(context: Context): File {
        val base = context.externalCacheDir ?: context.cacheDir
        val dir = File(base, DIR_NAME)
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    fun clear(context: Context) {
        dir(context).listFiles()?.forEach { it.deleteRecursively() }
    }

    /**
     * 把媒体（`content://` 或普通路径）复制进受管理的缓存目录，返回新路径。
     *
     * **所有** URI → 文件的转换都必须走这里，包括各处的兜底路径。
     * PictureSelector 自带的 `SandboxTransformUtils` 会写到
     * `getExternalFilesDir(DIRECTORY_PICTURES/MOVIES)` —— 那是持久化的应用专属目录，
     * [clear] 清不到，文件会一直堆积。所以本库完全不使用它。
     *
     * @return 新文件的绝对路径；失败返回 null（调用方自行决定是报错还是沿用原路径）。
     */
    fun copyIntoCache(context: Context, srcPath: String?, mimeType: String?): String? {
        if (srcPath.isNullOrEmpty()) return null

        val target = File(dir(context), "media_${System.nanoTime()}.${extensionFor(srcPath, mimeType)}")

        val input = try {
            if (srcPath.startsWith("content://")) {
                context.contentResolver.openInputStream(Uri.parse(srcPath))
            } else {
                File(srcPath).takeIf { it.exists() }?.inputStream()
            }
        } catch (_: Throwable) {
            null
        } ?: return null

        return try {
            input.use { source ->
                target.outputStream().use { sink -> source.copyTo(sink) }
            }
            target.absolutePath.takeIf { target.length() > 0 }
        } catch (_: Throwable) {
            target.delete()
            null
        }
    }

    private fun extensionFor(srcPath: String, mimeType: String?): String {
        mimeType?.substringAfterLast('/', "")
            ?.takeIf { it.isNotEmpty() && it.length <= 5 }
            ?.let { return if (it == "jpeg") "jpg" else it }

        return srcPath.substringAfterLast('.', "")
            .takeIf { it.isNotEmpty() && it.length <= 5 }
            ?: "dat"
    }
}
