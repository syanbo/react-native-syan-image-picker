package com.syanpicker

/**
 * 选择器启动闸门：占用与 [debounceMs] 防抖共用一把锁。
 *
 * 预览只预约时间戳、不占坑。时钟可注入，便于纯 JVM 测试。
 */
internal class LaunchGate(
    private val debounceMs: Long,
    private val now: () -> Long,
) {

    class Token internal constructor()

    private val lock = Any()
    private var occupant: Token? = null
    private var lastLaunchAt: Long? = null

    fun begin(): Token? = synchronized(lock) {
        val current = now()
        if (isBusy(current)) return null
        val token = Token()
        occupant = token
        lastLaunchAt = current
        token
    }

    fun reservePreview(): Boolean = synchronized(lock) {
        val current = now()
        if (isBusy(current)) return false
        lastLaunchAt = current
        true
    }

    fun finish(token: Token): Boolean = synchronized(lock) {
        if (occupant !== token) return false
        occupant = null
        true
    }

    private fun isBusy(current: Long): Boolean {
        if (occupant != null) return true
        val last = lastLaunchAt ?: return false
        return current - last < debounceMs
    }
}
