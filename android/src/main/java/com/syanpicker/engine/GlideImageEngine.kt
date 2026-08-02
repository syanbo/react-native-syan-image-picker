package com.syanpicker.engine

import android.content.Context
import android.widget.ImageView
import com.bumptech.glide.Glide
import com.luck.picture.lib.engine.ImageEngine
import com.luck.picture.lib.utils.ActivityCompatHelper
import com.syanpicker.R

/**
 * PictureSelector 的缩略图加载引擎。
 *
 * 占位图用的是本库自带的 [R.drawable.syan_picture_placeholder]，而不是
 * PictureSelector 的私有资源 —— 后者在 AGP 8 的 nonTransitiveRClass 下会编译失败。
 */
internal object GlideImageEngine : ImageEngine {

    private const val GRID_SIZE = 180
    private const val ALBUM_COVER_SIZE = 180

    override fun loadImage(context: Context, url: String, imageView: ImageView) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context).load(url).into(imageView)
    }

    override fun loadImage(
        context: Context,
        imageView: ImageView,
        url: String,
        maxWidth: Int,
        maxHeight: Int,
    ) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context)
            .load(url)
            .override(maxWidth, maxHeight)
            .into(imageView)
    }

    override fun loadAlbumCover(context: Context, url: String, imageView: ImageView) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context)
            .asBitmap()
            .load(url)
            .override(ALBUM_COVER_SIZE, ALBUM_COVER_SIZE)
            .sizeMultiplier(0.5f)
            .centerCrop()
            .placeholder(R.drawable.syan_picture_placeholder)
            .into(imageView)
    }

    override fun loadGridImage(context: Context, url: String, imageView: ImageView) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context)
            .load(url)
            .override(GRID_SIZE, GRID_SIZE)
            .centerCrop()
            .placeholder(R.drawable.syan_picture_placeholder)
            .into(imageView)
    }

    override fun pauseRequests(context: Context) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context).pauseRequests()
    }

    override fun resumeRequests(context: Context) {
        if (!ActivityCompatHelper.assertValidRequest(context)) return
        Glide.with(context).resumeRequests()
    }
}
