package com.syanpicker.engine

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class DeclaredPermissionInterceptorTest {

    private val read = "android.permission.READ_EXTERNAL_STORAGE"
    private val write = "android.permission.WRITE_EXTERNAL_STORAGE"

    @Test
    fun `宿主未声明 WRITE 时只申请 READ`() {
        val result = DeclaredPermissionInterceptor.filterDeclared(arrayOf(read, write), setOf(read))
        assertArrayEquals(arrayOf(read), result)
    }

    @Test
    fun `宿主声明了 WRITE 时原样申请`() {
        val result = DeclaredPermissionInterceptor.filterDeclared(arrayOf(read, write), setOf(read, write))
        assertArrayEquals(arrayOf(read, write), result)
    }

    @Test
    fun `读不到清单时原样申请`() {
        val result = DeclaredPermissionInterceptor.filterDeclared(arrayOf(read, write), null)
        assertArrayEquals(arrayOf(read, write), result)
    }

    @Test
    fun `全部未声明时返回空数组`() {
        val result = DeclaredPermissionInterceptor.filterDeclared(arrayOf(write), setOf(read))
        assertArrayEquals(emptyArray<String>(), result)
    }
}
