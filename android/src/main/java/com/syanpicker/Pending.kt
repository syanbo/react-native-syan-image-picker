package com.syanpicker

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap

/** 会被 reject 出去的错误码，与 TS 侧的 SyanErrorCode 一一对应。 */
internal enum class SyanErrorCode {
    PERMISSION_DENIED,
    NO_ACTIVITY,
    EXPORT_FAILED,
    UNSUPPORTED,
    BUSY,
}

internal fun cancelledResult(): WritableMap = Arguments.createMap().apply {
    putBoolean("cancelled", true)
    putArray("assets", Arguments.createArray())
}

internal fun successResult(assets: WritableArray): WritableMap =
    Arguments.createMap().apply {
        putBoolean("cancelled", false)
        putArray("assets", assets)
    }

/**
 * 单次请求的结算句柄。
 *
 * **每次调用都要新建一个**，由对应的 OnResultCallbackListener 独占持有。
 *
 * 早先的实现是模块级单例，两个隐患：旧选择器晚回来时会结算到新请求的 promise；
 * 新请求进来又会把旧请求"取消"掉。改成一次请求一个句柄之后，这两类串味在结构上
 * 就不可能发生了 —— 回调闭包里拿到的永远是它自己那一个。
 *
 * [OnceSettle] 保证结算幂等：无论触发多少条回调路径，promise 只会被结算一次。
 */
internal class PendingRequest(
    private val promise: Promise,
    /** 结算后触发；带上自身身份，避免旧请求误清掉模块级的新请求。 */
    private val onSettled: ((PendingRequest) -> Unit)? = null,
) {

    private val once = OnceSettle { onSettled?.invoke(this) }

    private fun settle(action: () -> Unit) = once.settle(action)

    fun resolve(assets: WritableArray) = settle {
        promise.resolve(successResult(assets))
    }

    fun cancel() = settle {
        promise.resolve(cancelledResult())
    }

    fun reject(code: SyanErrorCode, message: String) = settle {
        promise.reject(code.name, message)
    }
}
