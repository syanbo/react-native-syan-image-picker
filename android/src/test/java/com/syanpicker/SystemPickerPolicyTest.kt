package com.syanpicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemPickerPolicyTest {

    /* 门槛取值 ------------------------------------------------------------- */

    @Test
    fun `门槛先取清单 meta-data`() {
        assertEquals(36, SystemPickerPolicy.resolveMinSdk(manifestValue = 36, optionValue = 34))
    }

    @Test
    fun `清单未配置时取 JS 选项`() {
        assertEquals(34, SystemPickerPolicy.resolveMinSdk(manifestValue = null, optionValue = 34))
    }

    @Test
    fun `两处都未配置时缺省 33`() {
        assertEquals(33, SystemPickerPolicy.resolveMinSdk(manifestValue = null, optionValue = 0))
    }

    @Test
    fun `meta-data 原值解析`() {
        assertEquals(36, SystemPickerPolicy.parseMetaValue(36))
        assertEquals(36, SystemPickerPolicy.parseMetaValue(" 36 "))
        assertNull(SystemPickerPolicy.parseMetaValue("abc"))
        assertNull(SystemPickerPolicy.parseMetaValue(0))
        assertNull(SystemPickerPolicy.parseMetaValue(-1))
        assertNull(SystemPickerPolicy.parseMetaValue(36f))
        assertNull(SystemPickerPolicy.parseMetaValue(null))
    }

    /* 可用性 --------------------------------------------------------------- */

    @Test
    fun `Android 13 起系统 Picker 可用`() {
        assertTrue(SystemPickerPolicy.isAvailable(sdkInt = 33, rExtensionVersion = 0))
        assertTrue(SystemPickerPolicy.isAvailable(sdkInt = 36, rExtensionVersion = 0))
    }

    @Test
    fun `Android 11 和 12 要求 R 扩展版本至少为 2`() {
        assertTrue(SystemPickerPolicy.isAvailable(sdkInt = 30, rExtensionVersion = 2))
        assertTrue(SystemPickerPolicy.isAvailable(sdkInt = 32, rExtensionVersion = 5))
        assertFalse(SystemPickerPolicy.isAvailable(sdkInt = 31, rExtensionVersion = 1))
    }

    @Test
    fun `Android 10 及以下不可用`() {
        assertFalse(SystemPickerPolicy.isAvailable(sdkInt = 29, rExtensionVersion = 5))
    }

    @Test
    fun `三个条件同时满足才走系统 Picker`() {
        assertTrue(SystemPickerPolicy.shouldUse(36, minSdk = 36, available = true, resolvable = true))
        assertFalse(SystemPickerPolicy.shouldUse(35, minSdk = 36, available = true, resolvable = true))
        assertFalse(SystemPickerPolicy.shouldUse(36, minSdk = 36, available = false, resolvable = true))
        assertFalse(SystemPickerPolicy.shouldUse(36, minSdk = 36, available = true, resolvable = false))
    }

    /* Intent 参数与结果 ------------------------------------------------------ */

    @Test
    fun `单选不传 PICK_IMAGES_MAX`() {
        assertNull(SystemPickerPolicy.maxExtra(1))
    }

    @Test
    fun `多选传 maxCount 且不超过系统上限`() {
        assertEquals(9, SystemPickerPolicy.maxExtra(9))
        assertEquals(100, SystemPickerPolicy.maxExtra(500))
    }

    @Test
    fun `有 ClipData 时只读 ClipData`() {
        assertEquals(
            listOf("content://a", "content://b"),
            SystemPickerPolicy.collectUris("content://a", listOf("content://a", "content://b"), 9),
        )
    }

    @Test
    fun `单选读 getData`() {
        assertEquals(listOf("content://a"), SystemPickerPolicy.collectUris("content://a", emptyList(), 1))
    }

    @Test
    fun `结果为空视为取消`() {
        assertTrue(SystemPickerPolicy.collectUris(null, emptyList(), 9).isEmpty())
    }

    @Test
    fun `结果数不超过 maxCount`() {
        assertEquals(1, SystemPickerPolicy.collectUris(null, listOf("a", "b"), 1).size)
    }

    /* 选完后剔除 ----------------------------------------------------------- */

    private val allowAll = PickFilter(
        allowGif = true,
        allowWebp = true,
        allowBmp = true,
        allowHeic = true,
        maxFileSizeKb = 0,
        minFileSizeKb = 0,
    )

    private fun file(mime: String?, size: Long = 10_000L, path: String = "/cache/media_1.dat") =
        PickedFile(path, mime, size)

    @Test
    fun `allowGif 为 false 时剔除 GIF`() {
        val filter = allowAll.copy(allowGif = false)
        assertFalse(SystemPickerPolicy.accepts(file("image/gif"), filter))
        assertFalse(SystemPickerPolicy.accepts(file(null, path = "/cache/a.GIF"), filter))
        assertTrue(SystemPickerPolicy.accepts(file("image/jpeg"), filter))
        assertTrue(SystemPickerPolicy.accepts(file("image/gif"), allowAll))
    }

    @Test
    fun `WebP BMP HEIC 按各自开关剔除`() {
        assertFalse(SystemPickerPolicy.accepts(file("image/webp"), allowAll.copy(allowWebp = false)))
        assertFalse(SystemPickerPolicy.accepts(file("image/x-ms-bmp"), allowAll.copy(allowBmp = false)))
        assertFalse(SystemPickerPolicy.accepts(file("image/heif"), allowAll.copy(allowHeic = false)))
        assertFalse(SystemPickerPolicy.accepts(file("image/heic-sequence"), allowAll.copy(allowHeic = false)))
        assertTrue(SystemPickerPolicy.accepts(file("image/png"), allowAll.copy(allowHeic = false)))
    }

    @Test
    fun `超过 maxFileSize 的剔除，边界值保留`() {
        val filter = allowAll.copy(maxFileSizeKb = 500)
        assertTrue(SystemPickerPolicy.accepts(file("image/jpeg", size = 500 * 1024L), filter))
        assertFalse(SystemPickerPolicy.accepts(file("image/jpeg", size = 500 * 1024L + 1), filter))
    }

    @Test
    fun `小于 minFileSize 的剔除`() {
        val filter = allowAll.copy(minFileSizeKb = 10)
        assertFalse(SystemPickerPolicy.accepts(file("image/jpeg", size = 10 * 1024L - 1), filter))
        assertTrue(SystemPickerPolicy.accepts(file("image/jpeg", size = 10 * 1024L), filter))
    }

    /* 复制 ----------------------------------------------------------------- */

    @Test
    fun `全部复制成功时按原顺序返回路径`() {
        val outcome = SystemPickerPolicy.copyAll(
            listOf("content://a", "content://b"),
            copy = { "/cache/" + it.substringAfterLast('/') },
            discard = { },
        )
        assertEquals(CopyOutcome.Copied(listOf("/cache/a", "/cache/b")), outcome)
    }

    @Test
    fun `任一复制失败返回 EXPORT_FAILED 并删掉已复制的文件`() {
        val discarded = mutableListOf<String>()
        val outcome = SystemPickerPolicy.copyAll(
            listOf("content://a", "content://b", "content://c"),
            copy = { if (it == "content://b") null else "/cache/" + it.substringAfterLast('/') },
            discard = { discarded += it },
        )
        assertTrue(outcome is CopyOutcome.Failed)
        outcome as CopyOutcome.Failed
        assertEquals("content://b", outcome.source)
        assertEquals(SyanErrorCode.EXPORT_FAILED, outcome.code)
        assertEquals(listOf("/cache/a"), discarded)
    }

    @Test
    fun `复制抛异常与返回 null 同样处理`() {
        val outcome = SystemPickerPolicy.copyAll(
            listOf("content://a"),
            copy = { throw SecurityException("授权已失效") },
            discard = { },
        )
        assertEquals(CopyOutcome.Failed("content://a"), outcome)
    }
}
