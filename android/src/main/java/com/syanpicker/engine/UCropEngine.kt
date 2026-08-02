package com.syanpicker.engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.net.Uri
import android.widget.ImageView
import androidx.fragment.app.Fragment
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import com.luck.picture.lib.engine.CropFileEngine
import com.luck.picture.lib.utils.ActivityCompatHelper
import com.syanpicker.Cache
import com.syanpicker.CropConfig
import com.yalantis.ucrop.UCrop
import com.yalantis.ucrop.UCropActivity
import com.yalantis.ucrop.UCropImageEngine

/**
 * 基于 UCrop 的裁剪引擎。PictureSelector v3 同样把裁剪移出了核心。
 *
 * 用的是 `io.github.lucksiege:ucrop`，而不是 JitPack 上的
 * `com.github.yalantis:ucrop` —— 后者会强迫每个使用者去加 JitPack 仓库。
 */
internal class UCropEngine(private val config: CropConfig) : CropFileEngine {

    override fun onStartCrop(
        fragment: Fragment,
        srcUri: Uri,
        destinationUri: Uri,
        dataSource: ArrayList<String>,
        requestCode: Int,
    ) {
        val context = fragment.requireContext()

        val options = UCrop.Options().apply {
            setCircleDimmedLayer(config.circle)
            setShowCropFrame(config.showFrame)
            setShowCropGrid(config.showGrid)
            setFreeStyleCropEnabled(config.freeStyle)
            setCropOutputPathDir(Cache.dir(context).absolutePath)
            withAspectRatio(config.width.toFloat(), config.height.toFloat())

            // rotate / scale 通过手势开关表达。三个参数分别对应底部三个 tab。
            val gestures = when {
                config.rotate && config.scale -> UCropActivity.ALL
                config.scale -> UCropActivity.SCALE
                config.rotate -> UCropActivity.ROTATE
                else -> UCropActivity.NONE
            }
            setAllowedGestures(gestures, gestures, gestures)
        }

        val uCrop = UCrop.of(srcUri, destinationUri, dataSource)
        uCrop.withOptions(options)
        // 刻意**不**调用 withMaxResultSize：那个方法限制的是输出图片的**像素尺寸**，
        // 而 crop.width/height 表达的是裁剪框的宽高比与 UI 尺寸（默认约为屏宽的 60%，
        // 也就是两三百）。把它当作输出上限会把成图压到几百像素，白白丢掉分辨率。
        // iOS 侧的 TZ cropRect 同样只影响 UI，两端语义在此保持一致。
        uCrop.setImageEngine(GlideUCropImageEngine)
        uCrop.start(context, fragment, requestCode)
    }
}

private object GlideUCropImageEngine : UCropImageEngine {

    override fun loadImage(context: Context, url: String, imageView: ImageView) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context).load(url).into(imageView)
    }

    override fun loadImage(
        context: Context,
        url: Uri,
        maxWidth: Int,
        maxHeight: Int,
        call: UCropImageEngine.OnCallbackListener<Bitmap>?,
    ) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context)
            .asBitmap()
            .load(url)
            .override(maxWidth, maxHeight)
            .into(object : CustomTarget<Bitmap>() {
                override fun onResourceReady(
                    resource: Bitmap,
                    transition: Transition<in Bitmap>?,
                ) {
                    call?.onCall(resource)
                }

                override fun onLoadCleared(placeholder: Drawable?) {
                    // 必须回调，否则 UCrop 会一直等这张图。
                    call?.onCall(null)
                }
            })
    }
}
