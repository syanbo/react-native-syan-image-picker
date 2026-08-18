package com.syanpicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class OnceSettleTest {

    @Test
    fun `OnceSettle 只结算一次`() {
        var runs = 0
        val once = OnceSettle()
        once.settle { runs++ }
        once.settle { runs++ }
        assertEquals(1, runs)
    }

    @Test
    fun `onSettled 收到自身身份`() {
        var received: OnceSettle? = null
        val once = OnceSettle { received = it }
        once.settle { }
        assertSame(once, received)
    }

    @Test
    fun `settle 抛错后仍会调用 onSettled`() {
        var received: OnceSettle? = null
        val once = OnceSettle { received = it }
        try {
            once.settle { throw IllegalStateException("boom") }
            fail("settle 应把 action 的异常抛出")
        } catch (error: IllegalStateException) {
            assertEquals("boom", error.message)
        }
        assertSame(once, received)
    }
}

class LaunchGateTest {

    private class Clock(var now: Long = 10_000L)

    private fun gate(clock: Clock, debounceMs: Long = 600L) =
        LaunchGate(debounceMs) { clock.now }

    @Test
    fun `占用中 begin 返回 null`() {
        val clock = Clock()
        val gate = gate(clock)
        assertNotNull(gate.begin())
        assertNull(gate.begin())
    }

    @Test
    fun `结算后防抖窗口内 begin 仍失败`() {
        val clock = Clock(10_000L)
        val gate = gate(clock)
        val token = gate.begin()
        assertNotNull(token)
        assertTrue(gate.finish(token!!))
        clock.now = 10_599L
        assertNull(gate.begin())
        clock.now = 10_600L
        assertNotNull(gate.begin())
    }
}
