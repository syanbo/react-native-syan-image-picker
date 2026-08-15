package com.syanpicker

import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * 把 EXIF 的 8 种方向归一成“旋转 + 水平镜像”。
 *
 * 方向 4/5/7 的垂直镜像、转置和横向转置都可以由这两个操作组合得到；这样尺寸
 * 计算与 Bitmap 矩阵共用同一份方向定义，不会各自漏掉一半情况。
 */
internal data class ExifTransform(
    val rotationDegrees: Int,
    val flipHorizontal: Boolean,
) {
    val swapsDimensions: Boolean
        get() = rotationDegrees == 90 || rotationDegrees == 270

    val isIdentity: Boolean
        get() = rotationDegrees == 0 && !flipHorizontal
}

/**
 * 压缩计划的计算 —— **纯函数，无任何平台 API 依赖**。
 *
 * iOS 侧有一份逐行对应的实现（`SYCompressPlan`）。两边必须保持一致：
 * 这是"自动模式两端输出像素尺寸完全相同"这条契约的落点，改动时请同步修改并
 * 更新两侧的对拍用例。
 */
internal object CompressPlan {

    /* 自适应算法的常量表，与微信/Luban 同源。改这些数字会直接改变输出尺寸。 */
    private const val RATIO_9_16 = 0.5625
    private const val RATIO_1_2 = 0.5
    private const val LONG_SIDE_SMALL = 1664
    private const val LONG_SIDE_MEDIUM = 4990
    private const val LONG_SIDE_LARGE = 10240
    private const val BASE_LONG_SIDE = 1280

    /**
     * 自动模式的降采样倍率。
     *
     * 取值逻辑：接近方形的图按长边分档；越窄长的图越激进地压向 1280 基准长边。
     */
    fun autoSampleSize(width: Int, height: Int): Int {
        if (width <= 0 || height <= 0) return 1

        // 先偶数化 —— 原算法如此，奇数边会让后续整除产生偏差。
        val w = if (width % 2 == 1) width + 1 else width
        val h = if (height % 2 == 1) height + 1 else height

        val longSide = max(w, h)
        val shortSide = min(w, h)
        val ratio = shortSide.toDouble() / longSide.toDouble()

        val raw = when {
            ratio > RATIO_9_16 -> when {
                longSide < LONG_SIDE_SMALL -> 1
                longSide < LONG_SIDE_MEDIUM -> 2
                longSide < LONG_SIDE_LARGE -> 4
                else -> longSide / BASE_LONG_SIDE
            }

            ratio > RATIO_1_2 -> longSide / BASE_LONG_SIDE

            else -> ceil(longSide / (BASE_LONG_SIDE / ratio)).toInt()
        }

        return normalizeSampleSize(raw)
    }

    /**
     * 归一化为 2 的幂。
     *
     * Android 的 `BitmapFactory` 本来就会把 `inSampleSize` 向下取整到 2 的幂，
     * 这里显式做掉，好让 iOS 能照着同一个数算出相同的目标尺寸 —— 否则两端
     * 尺寸对不上（iOS 的 ImageIO 可以是任意倍率）。
     */
    fun normalizeSampleSize(value: Int): Int {
        if (value <= 1) return 1
        var result = 1
        while (result * 2 <= value) {
            result *= 2
        }
        return result
    }

    /**
     * 手动模式：把 (width, height) 等比缩放进 maxWidth × maxHeight 的边界框。
     *
     * 任一上限传 0 表示该方向不限制。永远不放大。
     *
     * @return 目标尺寸；无需缩放时原样返回。
     */
    fun fitInside(width: Int, height: Int, maxWidth: Int, maxHeight: Int): Pair<Int, Int> {
        if (width <= 0 || height <= 0) return width to height

        var scale = 1.0
        if (maxWidth > 0) scale = min(scale, maxWidth.toDouble() / width)
        if (maxHeight > 0) scale = min(scale, maxHeight.toDouble() / height)

        if (scale >= 1.0) return width to height

        return max(1, (width * scale).toInt()) to max(1, (height * scale).toInt())
    }

    /**
     * EXIF 方向值 1–8 的完整映射。使用数字是为了让本文件保持纯 JVM、无需 Android API。
     * 其中 4/5/7 通过“旋转后水平镜像”等价表示垂直镜像/转置。
     */
    fun exifTransform(orientation: Int): ExifTransform = when (orientation) {
        2 -> ExifTransform(rotationDegrees = 0, flipHorizontal = true)
        3 -> ExifTransform(rotationDegrees = 180, flipHorizontal = false)
        4 -> ExifTransform(rotationDegrees = 180, flipHorizontal = true)
        5 -> ExifTransform(rotationDegrees = 90, flipHorizontal = true)
        6 -> ExifTransform(rotationDegrees = 90, flipHorizontal = false)
        7 -> ExifTransform(rotationDegrees = 270, flipHorizontal = true)
        8 -> ExifTransform(rotationDegrees = 270, flipHorizontal = false)
        else -> ExifTransform(rotationDegrees = 0, flipHorizontal = false)
    }

    /** 返回应用 EXIF 后用户实际看到的宽高。方向 5–8 需要交换坐标轴。 */
    fun uprightSize(width: Int, height: Int, orientation: Int): Pair<Int, Int> =
        if (exifTransform(orientation).swapsDimensions) height to width else width to height

    /** 手动压缩的上限是硬边界：任一解码尺寸超出目标都必须继续缩小。 */
    fun exceedsTarget(width: Int, height: Int, target: Pair<Int, Int>): Boolean =
        width > target.first || height > target.second

    /**
     * 把摆正坐标系中的目标尺寸换算回文件存储坐标系。
     *
     * BitmapFactory 解码出来的位图尚未应用 EXIF。方向为 5–8 中的 90°/270° 变换时，
     * 存储坐标与摆正坐标的宽高轴相反；若直接把摆正尺寸应用到原始位图，会先拉伸
     * 图片再旋转。180° 旋转不交换坐标轴。
     */
    fun targetBeforeRotation(target: Pair<Int, Int>, rotationDegrees: Int): Pair<Int, Int> {
        val normalized = ((rotationDegrees % 360) + 360) % 360
        return if (normalized == 90 || normalized == 270) {
            target.second to target.first
        } else {
            target
        }
    }
}
