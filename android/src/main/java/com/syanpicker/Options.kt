package com.syanpicker

import com.facebook.react.bridge.ReadableMap

/**
 * 跨桥请求的解析。
 *
 * JS 层保证传过来的对象是补全过的，但这里依然对每个 key 做 [ReadableMap.hasKey]
 * 保护 —— 老实现用无保护的 `getInt()` 直读，任何绕过 JS 直接调用原生的方式都会
 * 让它抛 NoSuchKeyException 崩掉。防御成本几乎为零，没有理由不做。
 */

internal data class CropConfig(
    val enabled: Boolean,
    val width: Int,
    val height: Int,
    val circle: Boolean,
    val showFrame: Boolean,
    val showGrid: Boolean,
    val freeStyle: Boolean,
    val rotate: Boolean,
    val scale: Boolean,
) {
    companion object {
        val DISABLED = CropConfig(
            enabled = false,
            width = 0,
            height = 0,
            circle = false,
            showFrame = true,
            showGrid = false,
            freeStyle = false,
            rotate = true,
            scale = true,
        )

        fun from(map: ReadableMap?): CropConfig {
            if (map == null || !map.boolOr("enabled", false)) return DISABLED
            return CropConfig(
                enabled = true,
                width = map.intOr("width", 0),
                height = map.intOr("height", 0),
                circle = map.boolOr("circle", false),
                showFrame = map.boolOr("showFrame", true),
                showGrid = map.boolOr("showGrid", false),
                freeStyle = map.boolOr("freeStyle", false),
                rotate = map.boolOr("rotate", true),
                scale = map.boolOr("scale", true),
            )
        }
    }
}

internal enum class CompressMode {
    NONE,
    AUTO,
    MANUAL;

    companion object {
        fun parse(value: String?): CompressMode = when (value) {
            "none" -> NONE
            "manual" -> MANUAL
            else -> AUTO // 缺省即自动，与 TS 侧一致
        }
    }
}

internal data class CompressConfig(
    val mode: CompressMode,
    val quality: Int,
    /** 0 表示不限制 */
    val maxWidth: Int,
    /** 0 表示不限制 */
    val maxHeight: Int,
    /** KB，小于该值直接跳过压缩 */
    val minSize: Int,
    val keepAlpha: Boolean,
) {
    val enabled: Boolean get() = mode != CompressMode.NONE

    companion object {
        fun from(map: ReadableMap?): CompressConfig = CompressConfig(
            mode = CompressMode.parse(map.stringOrNull("mode")),
            quality = map.intOr("quality", 90).coerceIn(1, 100),
            maxWidth = map.intOr("maxWidth", 0).coerceAtLeast(0),
            maxHeight = map.intOr("maxHeight", 0).coerceAtLeast(0),
            minSize = map.intOr("minSize", 100).coerceAtLeast(0),
            keepAlpha = map.boolOr("keepAlpha", false),
        )
    }
}

internal data class ImageRequest(
    val maxCount: Int,
    val minCount: Int,
    /** KB，0 表示不限制 */
    val maxFileSize: Int,
    val minFileSize: Int,
    val showCameraButton: Boolean,
    val allowGif: Boolean,
    val allowWebp: Boolean,
    val allowBmp: Boolean,
    val allowHeic: Boolean,
    val allowOriginal: Boolean,
    val includeBase64: Boolean,
    val keepOriginal: Boolean,
    val sortAscending: Boolean,
    val showSelectionIndex: Boolean,
    val wechatStyle: Boolean,
    val selectedUris: List<String>,
    val crop: CropConfig,
    val compress: CompressConfig,
) {
    companion object {
        fun from(map: ReadableMap?): ImageRequest = ImageRequest(
            maxCount = map.intOr("maxCount", 6).coerceAtLeast(1),
            minCount = map.intOr("minCount", 0).coerceAtLeast(0),
            maxFileSize = map.intOr("maxFileSize", 0).coerceAtLeast(0),
            minFileSize = map.intOr("minFileSize", 0).coerceAtLeast(0),
            showCameraButton = map.boolOr("showCameraButton", true),
            allowGif = map.boolOr("allowGif", false),
            allowWebp = map.boolOr("allowWebp", true),
            allowBmp = map.boolOr("allowBmp", true),
            allowHeic = map.boolOr("allowHeic", true),
            allowOriginal = map.boolOr("allowOriginal", false),
            includeBase64 = map.boolOr("includeBase64", false),
            keepOriginal = map.boolOr("keepOriginal", false),
            sortAscending = map.boolOr("sortAscending", true),
            showSelectionIndex = map.boolOr("showSelectionIndex", false),
            wechatStyle = map.boolOr("wechatStyle", false),
            selectedUris = map.stringListOr("selectedUris"),
            crop = CropConfig.from(map.mapOrNull("crop")),
            compress = CompressConfig.from(map.mapOrNull("compress")),
        )
    }
}

internal data class VideoRequest(
    val maxCount: Int,
    val minCount: Int,
    /** KB，0 表示不限制 */
    val maxFileSize: Int,
    val minFileSize: Int,
    val showCameraButton: Boolean,
    val sortAscending: Boolean,
    val selectedUris: List<String>,
    val maxDuration: Int,
    val minDuration: Int,
) {
    companion object {
        fun from(map: ReadableMap?): VideoRequest = VideoRequest(
            maxCount = map.intOr("maxCount", 1).coerceAtLeast(1),
            minCount = map.intOr("minCount", 0).coerceAtLeast(0),
            maxFileSize = map.intOr("maxFileSize", 0).coerceAtLeast(0),
            minFileSize = map.intOr("minFileSize", 0).coerceAtLeast(0),
            showCameraButton = map.boolOr("showCameraButton", true),
            sortAscending = map.boolOr("sortAscending", true),
            selectedUris = map.stringListOr("selectedUris"),
            maxDuration = map.intOr("maxDuration", 180).coerceAtLeast(0),
            minDuration = map.intOr("minDuration", 0).coerceAtLeast(0),
        )
    }
}

internal data class CaptureImageRequest(
    val includeBase64: Boolean,
    val keepOriginal: Boolean,
    val crop: CropConfig,
    val compress: CompressConfig,
) {
    companion object {
        fun from(map: ReadableMap?): CaptureImageRequest = CaptureImageRequest(
            includeBase64 = map.boolOr("includeBase64", false),
            keepOriginal = map.boolOr("keepOriginal", false),
            crop = CropConfig.from(map.mapOrNull("crop")),
            compress = CompressConfig.from(map.mapOrNull("compress")),
        )
    }
}

internal data class PreviewRequest(
    val uris: List<String>,
    val index: Int,
) {
    companion object {
        fun from(map: ReadableMap?): PreviewRequest = PreviewRequest(
            uris = map.stringListOr("uris"),
            index = map.intOr("index", 0).coerceAtLeast(0),
        )
    }
}

internal data class CaptureVideoRequest(val recordDuration: Int) {
    companion object {
        fun from(map: ReadableMap?): CaptureVideoRequest = CaptureVideoRequest(
            recordDuration = map.intOr("recordDuration", 60).coerceAtLeast(1),
        )
    }
}

/* -------------------------------------------------------------------------- */
/* ReadableMap 读取工具                                                        */
/* -------------------------------------------------------------------------- */

private fun ReadableMap?.has(key: String): Boolean =
    this != null && hasKey(key) && !isNull(key)

internal fun ReadableMap?.boolOr(key: String, fallback: Boolean): Boolean =
    if (this.has(key)) this!!.getBoolean(key) else fallback

/**
 * 用 getDouble 而不是 getInt —— JS 的数字过桥后一律是 double，
 * 某些 RN 版本的 getInt() 在拿到 double 时会抛异常。
 */
internal fun ReadableMap?.intOr(key: String, fallback: Int): Int =
    if (this.has(key)) this!!.getDouble(key).toInt() else fallback

internal fun ReadableMap?.mapOrNull(key: String): ReadableMap? =
    if (this.has(key)) this!!.getMap(key) else null

internal fun ReadableMap?.stringOrNull(key: String): String? =
    if (this.has(key)) runCatching { this!!.getString(key) }.getOrNull() else null

internal fun ReadableMap?.stringListOr(key: String): List<String> {
    if (!this.has(key)) return emptyList()
    val array = this!!.getArray(key) ?: return emptyList()
    return (0 until array.size()).mapNotNull { index ->
        runCatching { array.getString(index) }.getOrNull()?.takeIf { it.isNotEmpty() }
    }
}
