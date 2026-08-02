package com.syanpicker

import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

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
}
