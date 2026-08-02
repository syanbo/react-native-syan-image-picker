package com.syanpicker

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

/**
 * 老实现里还留着 `createJSModules()` —— 那个方法早已不在 ReactPackage 接口上，
 * 属于纯粹的死代码，这里不再保留。
 */
class RNSyanImagePickerPackage : ReactPackage {

    // 新版 RN 已把 createNativeModules 标记为废弃，推荐改用 BaseReactPackage
    // 的 getModule()。但那套 API 在 RN 0.67 上并不存在，而本库的支持下限就是
    // 0.67.5，因此这里继续用 ReactPackage，并显式压制废弃告警。
    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun createNativeModules(
        reactContext: ReactApplicationContext,
    ): List<NativeModule> = listOf(RNSyanImagePickerModule(reactContext))

    override fun createViewManagers(
        reactContext: ReactApplicationContext,
    ): List<ViewManager<*, *>> = emptyList()
}
