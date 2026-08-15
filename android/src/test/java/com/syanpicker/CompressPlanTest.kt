package com.syanpicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 压缩算法一致性测试。
 *
 * 读取 `__fixtures__/compress-plan.json` —— **与 iOS 的 plan_test.m 是同一份文件**。
 * 这是整套测试策略的关键：两端各自维护期望值的话，改了一侧只会让那一侧的测试
 * 跟着改绿，漂移照样发生。共用 fixture 之后，任何一端偏离都会立刻红。
 *
 * 纯 JVM 测试，不需要设备或模拟器：`CompressPlan` 刻意不依赖任何 Android API。
 * 编解码那半边（BitmapFactory / EXIF / alpha）无法在 JVM 上测，由 iOS 侧的
 * codec_test 间接保护共享算法，Android 平台特有的部分见 docs/QA-CHECKLIST.md。
 */
class CompressPlanTest {

    private data class Case(
        val name: String,
        val width: Int,
        val height: Int,
        val sampleSize: Int,
        val outWidth: Int,
        val outHeight: Int,
    )

    /** 定位仓库根目录下的 fixture。测试的工作目录是 android/ 模块目录。 */
    private fun loadCases(): List<Case> {
        val candidates = listOf(
            File("../__fixtures__/compress-plan.json"),
            File("__fixtures__/compress-plan.json"),
        )
        val file = candidates.firstOrNull { it.exists() }
            ?: error("找不到 compress-plan.json，尝试过：${candidates.joinToString()}")

        // 手写解析，避免为一个固定格式的小文件引入 JSON 依赖。
        val objectPattern = Regex("""\{[^}]*}""")
        val numberPattern = Regex(""""(\w+)"\s*:\s*(\d+)""")
        val namePattern = Regex(""""name"\s*:\s*"([^"]*)"""")

        return objectPattern.findAll(file.readText()).map { match ->
            val block = match.value
            val numbers = numberPattern.findAll(block)
                .associate { it.groupValues[1] to it.groupValues[2].toInt() }
            Case(
                name = namePattern.find(block)?.groupValues?.get(1) ?: "?",
                width = numbers.getValue("width"),
                height = numbers.getValue("height"),
                sampleSize = numbers.getValue("sampleSize"),
                outWidth = numbers.getValue("outWidth"),
                outHeight = numbers.getValue("outHeight"),
            )
        }.toList()
    }

    @Test
    fun `fixture 能被正确加载`() {
        val cases = loadCases()
        assertTrue("fixture 至少应有 10 个用例，实际 ${cases.size}", cases.size >= 10)
    }

    @Test
    fun `自动模式倍率与 iOS 完全一致`() {
        loadCases().forEach { case ->
            assertEquals(
                "${case.name} (${case.width}x${case.height}) 的倍率",
                case.sampleSize,
                CompressPlan.autoSampleSize(case.width, case.height),
            )
        }
    }

    @Test
    fun `自动模式输出尺寸与 iOS 完全一致`() {
        loadCases().forEach { case ->
            val sample = CompressPlan.autoSampleSize(case.width, case.height)
            val outWidth =
                if (case.width == 0) 0 else Math.ceil(case.width.toDouble() / sample).toInt()
            val outHeight =
                if (case.height == 0) 0 else Math.ceil(case.height.toDouble() / sample).toInt()

            assertEquals("${case.name} 输出宽", case.outWidth, outWidth)
            assertEquals("${case.name} 输出高", case.outHeight, outHeight)
        }
    }

    @Test
    fun `倍率永远是 2 的幂 —— 这是两端尺寸一致的前提`() {
        assertEquals(1, CompressPlan.normalizeSampleSize(0))
        assertEquals(1, CompressPlan.normalizeSampleSize(1))
        assertEquals(2, CompressPlan.normalizeSampleSize(3))
        assertEquals(4, CompressPlan.normalizeSampleSize(7))
        assertEquals(8, CompressPlan.normalizeSampleSize(8))
        assertEquals(64, CompressPlan.normalizeSampleSize(100))
    }

    @Test
    fun `fitInside 等比缩放进边界框`() {
        assertEquals(1000 to 750, CompressPlan.fitInside(4000, 3000, 1000, 0))
        assertEquals(4000 to 3000, CompressPlan.fitInside(4000, 3000, 0, 0))
    }

    @Test
    fun `fitInside 取更紧的一边`() {
        val (_, height) = CompressPlan.fitInside(4000, 3000, 1000, 500)
        assertEquals(500, height)
    }

    @Test
    fun `fitInside 永不放大`() {
        assertEquals(800 to 600, CompressPlan.fitInside(800, 600, 2000, 2000))
    }

    @Test
    fun `方向 6 和 8 应在旋转前交换目标宽高`() {
        // 文件存储为 4032x3024，EXIF 6/8 摆正后为 3024x4032。
        val uprightTarget = CompressPlan.fitInside(3024, 4032, 0, 1000)
        assertEquals(750 to 1000, uprightTarget)

        // 原始位图必须先在存储坐标中缩到 1000x750，旋转后才会得到 750x1000。
        assertEquals(
            1000 to 750,
            CompressPlan.targetBeforeRotation(uprightTarget, 90),
        )
        assertEquals(
            1000 to 750,
            CompressPlan.targetBeforeRotation(uprightTarget, 270),
        )
    }

    @Test
    fun `方向 1 和 3 不应交换目标宽高`() {
        val target = 750 to 1000
        assertEquals(target, CompressPlan.targetBeforeRotation(target, 0))
        assertEquals(target, CompressPlan.targetBeforeRotation(target, 180))
    }

    @Test
    fun `EXIF 八种方向应包含完整旋转与镜像信息`() {
        val expected = listOf(
            ExifTransform(0, false),
            ExifTransform(0, true),
            ExifTransform(180, false),
            ExifTransform(180, true),
            ExifTransform(90, true),
            ExifTransform(90, false),
            ExifTransform(270, true),
            ExifTransform(270, false),
        )
        expected.forEachIndexed { index, transform ->
            assertEquals("EXIF ${index + 1}", transform, CompressPlan.exifTransform(index + 1))
        }
    }

    @Test
    fun `EXIF 5 到 8 的显示宽高应交换`() {
        (1..4).forEach { orientation ->
            assertEquals(4032 to 3024, CompressPlan.uprightSize(4032, 3024, orientation))
        }
        (5..8).forEach { orientation ->
            assertEquals(3024 to 4032, CompressPlan.uprightSize(4032, 3024, orientation))
        }
    }

    @Test
    fun `手动压缩任一维度超出目标都必须精确缩放`() {
        assertEquals(true, CompressPlan.exceedsTarget(1001, 750, 1000 to 750))
        assertEquals(true, CompressPlan.exceedsTarget(1000, 751, 1000 to 750))
        assertEquals(false, CompressPlan.exceedsTarget(1000, 750, 1000 to 750))
        assertEquals(false, CompressPlan.exceedsTarget(999, 749, 1000 to 750))
    }

    @Test
    fun `零与负数不应导致崩溃或除零`() {
        assertEquals(1, CompressPlan.autoSampleSize(0, 0))
        assertEquals(1, CompressPlan.autoSampleSize(-1, 100))
        assertEquals(0 to 0, CompressPlan.fitInside(0, 0, 100, 100))
    }
}
