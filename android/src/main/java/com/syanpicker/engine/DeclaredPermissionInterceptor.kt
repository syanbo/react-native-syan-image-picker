package com.syanpicker.engine

import android.content.Context
import android.content.pm.PackageManager
import androidx.fragment.app.Fragment
import com.luck.picture.lib.interfaces.OnPermissionsInterceptListener
import com.luck.picture.lib.interfaces.OnRequestPermissionListener
import com.luck.picture.lib.permissions.PermissionChecker
import com.luck.picture.lib.permissions.PermissionResultCallback

/**
 * 只申请宿主清单里声明过的权限，其余仍走 PictureSelector 自带的申请流程。
 *
 * v3 在 Android 12 及以下读相册时成对申请 READ / WRITE_EXTERNAL_STORAGE，并要求全部授权。
 * 宿主没声明 WRITE 时系统会直接拒绝它，用户点了"允许"也会被判成拒绝。
 * 本库不在清单里补声明 WRITE：带 maxSdkVersion 的声明会在合并时限制宿主自己的声明。
 */
internal object DeclaredPermissionInterceptor : OnPermissionsInterceptListener {

    override fun requestPermission(
        fragment: Fragment,
        permissionArray: Array<String>,
        call: OnRequestPermissionListener,
    ) {
        val declared = filterDeclared(permissionArray, declaredPermissions(fragment.requireContext()))
        if (declared.isEmpty()) {
            call.onCall(permissionArray, true)
            return
        }
        PermissionChecker.getInstance().requestPermissions(
            fragment,
            declared,
            object : PermissionResultCallback {
                override fun onGranted() = call.onCall(declared, true)
                override fun onDenied() = call.onCall(declared, false)
            },
        )
    }

    override fun hasPermissions(fragment: Fragment, permissionArray: Array<String>): Boolean {
        val declared = filterDeclared(permissionArray, declaredPermissions(fragment.requireContext()))
        return PermissionChecker.checkSelfPermission(fragment.requireContext(), declared)
    }

    /** 读不到清单时原样返回，保持 v3 的默认行为。 */
    fun filterDeclared(requested: Array<String>, declared: Set<String>?): Array<String> {
        if (declared == null) return requested
        return requested.filter { it in declared }.toTypedArray()
    }

    // PackageInfoFlags 重载到 API 33 才有，compileSdk 31 的宿主编译不到，只能用旧重载。
    @Suppress("DEPRECATION")
    private fun declaredPermissions(context: Context): Set<String>? = try {
        context.packageManager
            .getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
            .requestedPermissions
            ?.toSet()
    } catch (t: Throwable) {
        null
    }
}
