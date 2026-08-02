package com.syanpicker.engine

import android.content.Context
import com.luck.picture.lib.engine.UriToFileTransformEngine
import com.luck.picture.lib.interfaces.OnKeyValueResultCallbackListener
import com.syanpicker.Cache

/**
 * 分区存储适配：把 `content://` 形式的媒体复制进应用沙箱，换成可直接读写的
 * 真实路径。不装这个引擎的话，Android 10+ 上拿到的路径 RN 侧多半读不了。
 *
 * 拷贝统一走 [Cache.copyIntoCache]，落在本库自己的缓存目录下，`clearCache()`
 * 能够回收。刻意**不使用** PictureSelector 的 `SandboxTransformUtils` ——
 * 它写到的是持久化的 `getExternalFilesDir`，清不掉。
 */
internal object SandboxEngine : UriToFileTransformEngine {

    override fun onUriToFileAsyncTransform(
        context: Context,
        srcPath: String?,
        mineType: String?,
        call: OnKeyValueResultCallbackListener?,
    ) {
        val copied = Cache.copyIntoCache(context, srcPath, mineType)

        // 回调必须触发 —— 少调一次，选择流程就永远停在这里。
        // 拷贝失败时传 null，PictureSelector 会沿用原始路径；这样虽然可能拿到
        // 不好读的 content:// 路径，但至少不会在受管理目录之外留下垃圾文件。
        call?.onCallback(srcPath, copied)
    }
}
