package com.syanpicker

import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import com.luck.picture.lib.interfaces.OnPermissionsInterceptListener

/**
 * 打开应用内相册之前，先在当前页面上调用宿主拦截器申请读权限。
 *
 * v3 的相册页启动以后才申请权限。权限被永久拒绝时，系统立刻返回拒绝，
 * 相册页空着显示一下就被关掉。先拿到权限再打开相册，就没有这个空页面。
 *
 * 拦截器拿到的是一个不显示界面的普通 Fragment，不是 PictureCommonFragment，
 * 所以只对宿主拦截器这样做；默认的 DeclaredPermissionInterceptor 依赖
 * PictureCommonFragment 接收授权结果。必须在主线程调用。
 */
internal object PermissionPreflight {

    private const val TAG = "syan-permission-preflight"

    fun request(
        activity: FragmentActivity,
        interceptor: OnPermissionsInterceptListener,
        permissions: Array<String>,
        onResult: (granted: Boolean) -> Unit,
    ) {
        val manager = activity.supportFragmentManager
        val host = Fragment()
        manager.beginTransaction().add(host, TAG).commitNowAllowingStateLoss()
        interceptor.requestPermission(host, permissions) { _, granted ->
            if (host.isAdded) {
                manager.beginTransaction().remove(host).commitAllowingStateLoss()
            }
            onResult(granted)
        }
    }
}
