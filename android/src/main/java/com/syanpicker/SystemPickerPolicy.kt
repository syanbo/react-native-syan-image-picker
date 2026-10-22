package com.syanpicker

/**
 * 系统 Photo Picker 分支的规则：门槛取值、可用性、Intent 参数、选完后的过滤与复制。
 *
 * 纯函数，不依赖 Android API，可在纯 JVM 下测试。读系统状态的部分在
 * [SystemImagePicker] 里，读到的值再交给这里判断。
 *
 * Intent 常量写成字符串字面量：`MediaStore.ACTION_PICK_IMAGES` 等要 compileSdk 33
 * 才有，而本库要在 compileSdk 31（RN 0.67.5 下限）下编译。
 */
internal object SystemPickerPolicy {

    const val ACTION_PICK_IMAGES = "android.provider.action.PICK_IMAGES"
    const val EXTRA_PICK_IMAGES_MAX = "android.provider.extra.PICK_IMAGES_MAX"

    /** 宿主清单 `<application>` 下 meta-data 的 name。 */
    const val META_MIN_SDK = "photo_picker_min_sdk"

    const val DEFAULT_MIN_SDK = 33

    /**
     * `MediaStore.getPickImagesMaxLimit()` 的值。该方法要 compileSdk 33 才有，这里写常量。
     * PICK_IMAGES_MAX 超过它时，系统 Picker 直接返回 RESULT_CANCELED。
     */
    const val PICK_IMAGES_MAX_LIMIT = 100

    /** Android 13 起系统自带 PICK_IMAGES。 */
    private const val BUILT_IN_SDK = 33

    /** Android 11 / 12 经 Google Play 系统更新拿到 R 扩展版本 2 后，也提供 PICK_IMAGES。 */
    private const val R_SDK = 30
    private const val MIN_R_EXTENSION = 2

    private const val KB = 1024L

    /** 清单 meta-data 的原始值 → 门槛。`android:value="36"` 读出来是 Int；写成字符串也接受。 */
    fun parseMetaValue(raw: Any?): Int? = when (raw) {
        is Int -> raw
        is String -> raw.trim().toIntOrNull()
        else -> null
    }?.takeIf { it > 0 }

    /**
     * 门槛取值顺序：宿主 meta-data → JS 选项 → 缺省 33。
     *
     * meta-data 排在 JS 选项前：宿主原生代码和 RN 读同一个门槛，热更下发的 JS
     * 改不动它，两边不会出现不一致。
     *
     * @param optionValue JS 选项 `systemPickerMinSdk`，0 表示未指定
     */
    fun resolveMinSdk(manifestValue: Int?, optionValue: Int): Int =
        manifestValue?.takeIf { it > 0 }
            ?: optionValue.takeIf { it > 0 }
            ?: DEFAULT_MIN_SDK

    /** @param rExtensionVersion `SdkExtensions.getExtensionVersion(R)`；SDK < 30 时传 0 */
    fun isAvailable(sdkInt: Int, rExtensionVersion: Int): Boolean =
        sdkInt >= BUILT_IN_SDK || (sdkInt >= R_SDK && rExtensionVersion >= MIN_R_EXTENSION)

    fun shouldUse(sdkInt: Int, minSdk: Int, available: Boolean, resolvable: Boolean): Boolean =
        sdkInt >= minSdk && available && resolvable

    /** PICK_IMAGES_MAX 的值；返回 null 表示不传。传 1 时系统 Picker 直接返回 RESULT_CANCELED。 */
    fun maxExtra(maxCount: Int): Int? =
        if (maxCount > 1) maxCount.coerceAtMost(PICK_IMAGES_MAX_LIMIT) else null

    /**
     * 从结果 Intent 取 URI：多选在 ClipData 里，单选在 getData() 里。
     * 有的实现两处都填，有 ClipData 时只读它，避免同一张图出现两次。
     */
    fun collectUris(data: String?, clip: List<String>, maxCount: Int): List<String> {
        val uris = clip.filter { it.isNotEmpty() }.ifEmpty { listOfNotNull(data?.takeIf { it.isNotEmpty() }) }
        return uris.distinct().take(maxCount.coerceAtLeast(1))
    }

    /**
     * 逐个复制。任一失败就删掉已复制的文件并返回 [CopyOutcome.Failed]：
     * 系统 Picker 的 URI 只在本次结果里临时授权，事后无法重读。
     */
    fun copyAll(
        uris: List<String>,
        copy: (String) -> String?,
        discard: (String) -> Unit,
    ): CopyOutcome {
        val copied = ArrayList<String>(uris.size)
        for (uri in uris) {
            val path = runCatching { copy(uri) }.getOrNull()
            if (path == null) {
                copied.forEach(discard)
                return CopyOutcome.Failed(uri)
            }
            copied += path
        }
        return CopyOutcome.Copied(copied)
    }

    /**
     * 系统 Picker 界面里不能按格式和大小过滤，选完后按与 PictureSelector 查询层相同的
     * 规则剔除。
     */
    fun accepts(file: PickedFile, filter: PickFilter): Boolean {
        when (formatOf(file)) {
            Format.GIF -> if (!filter.allowGif) return false
            Format.WEBP -> if (!filter.allowWebp) return false
            Format.BMP -> if (!filter.allowBmp) return false
            Format.HEIC -> if (!filter.allowHeic) return false
            Format.OTHER -> Unit
        }
        if (filter.maxFileSizeKb > 0 && file.sizeBytes > filter.maxFileSizeKb * KB) return false
        if (filter.minFileSizeKb > 0 && file.sizeBytes < filter.minFileSizeKb * KB) return false
        return true
    }

    private enum class Format { GIF, WEBP, BMP, HEIC, OTHER }

    /** 先看 MIME，取不到再看扩展名。 */
    private fun formatOf(file: PickedFile): Format {
        val mime = file.mimeType?.lowercase().orEmpty()
        val ext = file.path.substringBefore('?').substringAfterLast('.', "").lowercase()
        return when {
            mime == "image/gif" || (mime.isEmpty() && ext == "gif") -> Format.GIF
            mime == "image/webp" || (mime.isEmpty() && ext == "webp") -> Format.WEBP
            mime == "image/bmp" || mime == "image/x-ms-bmp" ||
                (mime.isEmpty() && ext == "bmp") -> Format.BMP
            mime.startsWith("image/heic") || mime.startsWith("image/heif") ||
                (mime.isEmpty() && (ext == "heic" || ext == "heif")) -> Format.HEIC
            else -> Format.OTHER
        }
    }
}

internal sealed class CopyOutcome {
    data class Copied(val paths: List<String>) : CopyOutcome()

    data class Failed(val source: String) : CopyOutcome() {
        val code: SyanErrorCode get() = SyanErrorCode.EXPORT_FAILED
    }
}

/** 已复制进缓存的一张图。 */
internal data class PickedFile(
    val path: String,
    val mimeType: String?,
    val sizeBytes: Long,
)

internal data class PickFilter(
    val allowGif: Boolean,
    val allowWebp: Boolean,
    val allowBmp: Boolean,
    val allowHeic: Boolean,
    /** KB，0 表示不限制 */
    val maxFileSizeKb: Int,
    /** KB，0 表示不限制 */
    val minFileSizeKb: Int,
) {
    companion object {
        fun from(request: ImageRequest) = PickFilter(
            allowGif = request.allowGif,
            allowWebp = request.allowWebp,
            allowBmp = request.allowBmp,
            allowHeic = request.allowHeic,
            maxFileSizeKb = request.maxFileSize,
            minFileSizeKb = request.minFileSize,
        )
    }
}
