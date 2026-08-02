package com.syanpicker

import com.luck.picture.lib.style.PictureSelectorStyle
import com.luck.picture.lib.style.SelectMainStyle

/**
 * 选择器外观。
 *
 * PictureSelector v3 **不再提供内置的微信主题**（v2 的 `R.style.picture_WeChat_style`
 * 在 v3 中已不存在，AAR 里也查不到任何 wechat 相关的 style 资源）。完整复刻微信
 * 需要一整套颜色与图标资源，不在 1.0 的范围内。
 *
 * 因此 `style: 'wechat'` 在 Android 上落地为"带序号的选择态" —— 这是微信选择器
 * 最具辨识度、也是 v3 真正支持的特征。README 与迁移指南中对此有明确说明。
 *
 * 未显式设置的字段保持为 0，PictureSelector 内部会用 `StyleUtils.checkStyleValidity`
 * 过滤掉无效值并退回自身默认样式，所以这里不必把每个颜色都填满。
 */
internal object SelectorStyle {

    fun build(wechatStyle: Boolean, showSelectionIndex: Boolean): PictureSelectorStyle {
        val numbered = wechatStyle || showSelectionIndex

        val mainStyle = SelectMainStyle().apply {
            isSelectNumberStyle = numbered
            isPreviewSelectNumberStyle = numbered
        }

        return PictureSelectorStyle().apply {
            selectMainStyle = mainStyle
        }
    }
}
