package com.syanpicker

import java.util.concurrent.atomic.AtomicBoolean

/**
 * 保证 [settle] 的 action 只跑一次；即使 action 抛错，也会在 finally 里把自身交给 [onSettled]。
 */
internal class OnceSettle(
    private val onSettled: ((OnceSettle) -> Unit)? = null,
) {

    private val settled = AtomicBoolean(false)

    fun settle(action: () -> Unit) {
        if (!settled.compareAndSet(false, true)) return
        try {
            action()
        } finally {
            onSettled?.invoke(this)
        }
    }
}
