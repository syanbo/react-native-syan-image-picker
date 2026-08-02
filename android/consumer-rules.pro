# 随 AAR 一起下发给宿主 App 的 R8 规则。
# 没有这些规则时，release 构建可能出现缩略图空白，或在 LocalMedia 反序列化处崩溃。

# PictureSelector 的实体类会被 Parcel / 反射使用
-keep class com.luck.picture.lib.entity.** { *; }
-keep class com.luck.picture.lib.config.** { *; }
-keep interface com.luck.picture.lib.** { *; }
-dontwarn com.luck.picture.lib.**

# UCrop
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# 压缩为本库自研（CompressPlan / ImageCompressEngine），不再依赖 Luban，
# 因此这里无需任何压缩相关的 keep 规则。

# Glide
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep class * extends com.bumptech.glide.module.AppGlideModule { <init>(...); }
-keep public enum com.bumptech.glide.load.ImageHeaderParser$** {
    **[] $VALUES;
    public *;
}
-dontwarn com.bumptech.glide.**
