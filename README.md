# react-native-syan-image-picker

[![npm](https://img.shields.io/npm/v/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/dm/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![license](https://img.shields.io/npm/l/react-native-syan-image-picker.svg)](./LICENSE)

React Native 多图片选择组件，支持裁剪与压缩。

- Android：[PictureSelector](https://github.com/LuckSiege/PictureSelector) v3
- iOS：[TZImagePickerController](https://github.com/banchichen/TZImagePickerController) 3.8

> **1.0 是一次完全重写，API 全部重新设计。** 从 0.5.x 升级请先读
> [MIGRATION.md](./MIGRATION.md)。

## 特点

- **纯 Promise**，无 callback 重载
- **取消不是错误** —— 取消时正常 resolve，只有权限被拒、导出失败、`BUSY` 才 reject
- **库不持有任何状态** —— 选中态由调用方持有并回传
- **TypeScript 优先**，类型由源码生成，不会与运行时脱节
- 支持 Android 13 / 14 的媒体权限与"仅选择部分照片"
- 支持 iOS 14 的 Limited（"仅选中的照片"）授权

## 安装

```sh
npm install react-native-syan-image-picker
# iOS
cd ios && pod install
```

自 RN 0.60 起自动链接，无需 `react-native link`。

### iOS 权限文案

在 `Info.plist` 中按需添加：

| Key | 何时需要 |
|---|---|
| `NSPhotoLibraryUsageDescription` | 必需 |
| `NSCameraUsageDescription` | 使用 `captureImage` / `captureVideo` |
| `NSMicrophoneUsageDescription` | 使用 `captureVideo` |

### Android 权限

所需权限**由本库的 manifest 自动合入**，无需手动声明：

- `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_VISUAL_USER_SELECTED`
- `READ_EXTERNAL_STORAGE`（带 `maxSdkVersion="32"`）
- `CAMERA`

`CAMERA` 是必需的：PictureSelector 在拉起相机前会执行 `checkSelfPermission(CAMERA)`，
而 Android 对未在清单中声明的权限一律直接返回 DENIED 且不弹授权框 —— 不声明的话
`captureImage` / `captureVideo` 以及相册内的相机入口全部打不开。

> 若你的 App 完全不用拍摄功能，又不希望在 Play 审核中解释相机权限，可在自己的
> manifest 中用 `tools:node="remove"` 移除它。

## 快速开始

```ts
import { pickImage, isSyanError } from 'react-native-syan-image-picker';

const res = await pickImage({ maxCount: 9 });
if (res.cancelled) return;          // 取消：正常返回，不是异常
res.assets.forEach((a) => console.log(a.uri, a.width, a.height));
```

默认导出同样可用：

```ts
import SYImagePicker from 'react-native-syan-image-picker';
await SYImagePicker.pickImage();
```

## API

五个方法，全部返回 Promise：

```ts
pickImage(options?):    Promise<PickResult<ImageAsset>>
pickVideo(options?):    Promise<PickResult<VideoAsset>>
captureImage(options?): Promise<PickResult<ImageAsset>>
captureVideo(options?): Promise<PickResult<VideoAsset>>
clearCache():           Promise<void>
```

本库不提供结果预览。选完之后用宿主自己的图片组件展示 `uri` 即可。

`clearCache` 清空本库写入的缓存目录（压缩 / 裁剪产物、视频封面）。

> **警告：** 在任意 `pick*` / `capture*` 的 Promise **尚未 settle** 时调用
> `clearCache` 是**未定义行为**。它可能删掉正在写出的文件，让随后 resolve
> 的 `file://` 变成 404，或触发 `EXPORT_FAILED`。请等对应 Promise 完成后再清。

### 返回值

```ts
type PickResult<T> =
  | { cancelled: true;  assets: [] }
  | { cancelled: false; assets: T[] }
```

`ImageAsset`：`uri` · `width` · `height` · `size` · `fileName?` · `assetId?` ·
`originalUri?`（需 `keepOriginal: true`） · `base64?`（需 `includeBase64: true`）

`VideoAsset`：`uri` · `width` · `height` · `size` · `duration`(ms) · `mime` ·
`coverUri` · `fileName?` · `assetId?`

> `base64` 是**裸编码，不含 `data:image/jpeg;base64,` 前缀** —— 前缀请按需自行拼接。

> `cancelled: false` 也可能配空数组：iOS 上 `maxFileSize` / `allowGif` 是在结果
> 返回前剔除的，选中项可能被全部剔除。**不要假设 `!cancelled` 就一定有元素。**

选择"原图"、`compress: false`、以及 GIF 这三种情况会**原样落盘相册中的原始字节**，
不做任何重编码 —— GIF 动画、PNG 透明通道、原始容器格式都得以保留。

开启压缩时输出格式按**图片实际是否含透明通道**决定：有 alpha 自动输出 PNG
（透明不会丢），没有 alpha（含截图这类不透明 PNG）转 JPEG 以拿到体积收益。
`keepAlpha: true` 可强制输出 PNG。

### 错误

只有真正的异常才 reject，`error.code` 为以下之一：

| code | 含义 |
|---|---|
| `PERMISSION_DENIED` | 用户拒绝了相册 / 相机权限 |
| `NO_ACTIVITY` | Android：当前没有可用的 Activity |
| `EXPORT_FAILED` | 导出、写盘或压缩失败 |
| `UNSUPPORTED` | 当前平台 / 设备不支持该能力 |
| `BUSY` | 两端拒绝并发原生 UI；Android 另含 600ms 防抖 |

> 两端同一时刻只允许一个会展示原生 UI 的请求（相册 / 相机 / 预览）。
> Android 的 PictureSelector 另外还有 600ms 防重复点击窗口，窗口内的第二次启动
> 会被它**静默丢弃**，因此库会提前 reject `BUSY`。收到它通常意味着按钮需要防抖，
> 或在等待期间禁用入口。

```ts
try {
  await pickImage();
} catch (e) {
  if (isSyanError(e) && e.code === 'PERMISSION_DENIED') {
    // 引导用户去设置里开启权限
  }
}
```

### 选项

```ts
await pickImage({
  maxCount: 6,
  minCount: 0,              // 至少选够几张才能完成
  maxFileSize: 0,           // KB，0 = 不限制
  showCameraButton: true,
  allowGif: false,
  allowWebp: true,          // 仅 Android
  allowBmp: true,           // 仅 Android
  allowHeic: true,          // 仅 Android
  allowOriginal: false,
  includeBase64: false,
  sortOrder: 'asc',
  showSelectionIndex: false,
  style: 'default',
  selectedAssets: previous.assets,   // 回填选中态

  crop: {                            // 不传 = 不裁剪
    width: 300, height: 300,
    shape: 'rect',
  },
  compress: 'auto',                  // 不传即为 'auto'，详见下节
});
```

### 压缩

`compress` 有四种取值：

| 取值 | 行为 |
|---|---|
| 不传 | **自动模式**（默认） |
| `'auto'` | 同上，显式写法 |
| `{ ... }` | 手动模式，参数见下 |
| `false` | 完全不压缩，原样返回相册中的字节 |

**自动模式**采用与微信/Luban 同源的启发式：按长边与长宽比自动挑选降采样倍率
（倍率取 2 的幂），再以质量 60 编码。**两端跑的是同一套算法，输出像素尺寸完全一致**
（详见 [compress-parity.md](./docs/compress-parity.md)）。

**手动模式**的参数两端行为一致：

```ts
await pickImage({
  compress: {
    quality: 85,        // 1–100，默认 90
    maxWidth: 1920,     // 边界框；不传 = 不限制
    maxHeight: 1920,
    minSize: 100,       // 源文件小于 100KB 就跳过压缩
    keepAlpha: false,
  },
});
```

`maxWidth` / `maxHeight` 构成一个**边界框**，图片按原比例缩放到刚好放得进去，
永远不放大。降采样比调 `quality` 有效得多 —— 分辨率减半约省 75% 体积，
而质量 90→70 只省 40% 左右，所以优先用尺寸上限。

`crop` 的默认值方向与 `compress` **相反**：不传 `crop` 就是不裁剪。

### 记住上次的选择

本库不持有任何全局选中态，把上次的结果传回即可：

```ts
const first = await pickImage();
const second = await pickImage({ selectedAssets: first.assets });
```

### 处理进度

选完之后还有压缩、编码、写盘要做。默认 iOS 会让选择器**停在原地转圈**再退出
（Android 由 PictureSelector 自己显示 loading），所以通常什么都不用管。

想自己渲染进度 UI 时，关掉原生 loading 并订阅事件：

```ts
import { addProgressListener, pickImage } from 'react-native-syan-image-picker';

const sub = addProgressListener(({ completed, total }) => {
  setHint(`处理中 ${completed}/${total}`);
});

await pickImage({ showLoading: false });
sub.remove();
```

**订阅本身就是开关** —— 没有监听者时原生一条事件都不发，零开销。

第一条进度事件的到达还有个额外含义：**选择器已经关了、开始处理了**。
promise 从调用那一刻就挂着，但那之前用户还在相册里挑图，光看 promise 分不清。

## 平台差异

这些差异源自底层库的能力边界，已在类型定义中逐条标注：

| 选项 | 说明 |
|---|---|
| `crop.freeStyle` / `rotate` / `scale` | **仅 Android**（UCrop 的能力） |
| `crop` 于 `captureImage` | iOS 使用系统自带编辑界面，`width` / `height` 不生效 |
| `crop` 于多选 | 仅 `maxCount: 1` 时生效，多选时忽略 |
| `crop.width/height` | 两端均只决定**裁剪框的宽高比与 UI 尺寸**，不限制输出分辨率 |
| `video.maxDuration/minDuration` | Android 在选择界面内过滤；iOS 的 TZ 不支持按时长筛选，改为在结果返回前剔除（用户能选中，但不会出现在 `assets` 里） |
| `maxFileSize/minFileSize` | 同上：Android 在界面内过滤；iOS 选完后剔除。iOS 没有廉价的公开 API 能读 PHAsset 文件大小（`PHAssetResource` 不暴露 `fileSize`，只有私有 KVC 能拿），因此改为对**已选中的少数资源**用 `requestContentEditingInput` 取原始文件 URL 后 stat |
| GIF | 两端都**不压缩**，原样返回 —— 重编码只会拿到第一帧 |
| `allowGif: false` | Android 在查询层过滤，GIF 不出现在列表里；iOS 的 TZ 做不到隐藏（其 `allowPickingGif=NO` 只是"当作普通图片"），改为在结果返回前剔除 |
| `allowWebp` / `allowBmp` / `allowHeic` | **仅 Android**（查询层过滤）。iOS 无对应能力，但通常不需要 —— 默认会重编码为 JPEG，只有"原图" / `compress: false` / GIF 才透传原始字节 |
| `style: 'wechat'` | Android 上表现为**带序号的选择态**。**iOS 是 no-op**（不是部分主题）。PictureSelector v3 已移除内置微信主题，完整复刻需要整套资源，不在 1.0 范围内 |
| `showLoading` | **仅 iOS**。Android 由 PictureSelector 自己在压缩阶段转圈 |
| `transcode` | **仅 iOS**。Android 不重新编码视频 |

不支持的选项在运行时**静默忽略**，不会报错。

## 兼容性

| 项 | 要求 |
|---|---|
| React Native | **>= 0.67.5** |
| Android | minSdk 21，compileSdk 建议 34+ |
| iOS | 11.0+ |
| 架构 | 目前仅 Old Architecture（经 interop 层可在新架构下运行） |

### 两点必须知道的注意事项

**1. Android 13+ 需要 compileSdk 33 以上。**
`READ_MEDIA_IMAGES` 等权限需要 compileSdk >= 33 才会生效。停留在 RN 0.67 默认
compileSdk 31 的工程，**拿不到 Android 13+ 的相册能力**。请在
`android/build.gradle` 的 `ext` 中提升：

```gradle
ext {
    compileSdkVersion = 34
    targetSdkVersion = 34
}
```

**2. 本库的 Android 端使用 Kotlin。**
它会自带 Kotlin Gradle 插件（RN 0.73+ 用 2.1.20，更早版本用 1.8.22 —— Kotlin 1.9+
要求 Gradle 7.6.3，而 RN 0.67 用的是 Gradle 7.3）。若与你工程的 Kotlin 版本冲突，
在根 `build.gradle` 的 `ext` 中指定即可：

```gradle
ext {
    kotlinVersion = '2.1.20'
}
```

同理可覆盖 `pictureSelectorVersion`、`glideVersion`。

## 本地开发

仓库内有两个验证工程：

| 目录 | 作用 |
|---|---|
| `example/` | 完整的 RN 示例 App，**直接消费本地源码**。入口覆盖选图 / 裁剪 / base64 / 不压缩 / 视频 / 拍照 / 录像 / 回填 / keepOriginal / 关闭 loading + 进度 / GIF / 清缓存 |
| `example-rn067/` | RN 0.67.5 支持下限的构建验证 |

```sh
npm install
npm --prefix example install

# Android
cd example/android && ./gradlew :app:assembleDebug
# iOS
cd example/ios && pod install && cd .. && npx react-native run-ios
```

`example-rn067/` **不是**完整 App，而是一个只做构建验证的 Gradle 工程 ——
RN 0.67 的模板依赖已下线的 jcenter，其 iOS 工程也无法用现代 Xcode 构建，硬凑一个
完整 App 出来只会变成永远修不好的负担。真正要守住的是"库能在那套老工具链下编过"：

```sh
npm --prefix example-rn067 install   # RN 0.71 之前的 AAR 随 npm 包下发
cd example-rn067 && gradle :react-native-syan-image-picker:assembleRelease
```

跨进程的相册 / 相机 / 权限 UI 无法自动化测试。发 `1.0.0` 请对照
[docs/QA-CHECKLIST.md](./docs/QA-CHECKLIST.md) 的「1.0.0 发版门槛」；
完整设备矩阵是维护期回归。

## 许可

MIT
