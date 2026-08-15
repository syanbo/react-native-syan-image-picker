# 从 0.5.x 升级到 1.0

1.0 是一次**完全重写**，API 全部重新设计。0.5.x 的调用代码需要改，但改动是机械的，
下面按类别列全。

## 一、为什么要重写

0.5.3 停更于 2022-04，之后 Android 构建体系经历了两次断代：

- AGP 8 移除了 manifest 的 `package=`，而老版本没有 `namespace` → **编译失败**
- Android 13 起相册需要 `READ_MEDIA_IMAGES`，PictureSelector 2.7.3 完全不支持
  → **即使编译通过，相册也是空的**

同时老实现存在多处会让 Promise 永久挂起、静默返回损坏数据的缺陷（见文末）。

## 二、环境要求变化

| 项 | 0.5.x | 1.0 |
|---|---|---|
| React Native | 0.60+ | **>= 0.67.5** |
| Android minSdk | 16 | **21** |
| Android 语言 | Java | **Kotlin**（库自带插件，可用 `ext.kotlinVersion` 覆盖） |
| iOS 部署目标 | 7.0（名义上） | **11.0** |
| PictureSelector | v2.7.3 | **v3.11.3** |
| TZImagePicker | 未锁版本 | **~> 3.8.9** |

> RN 0.67 工程需自行把 `compileSdkVersion` 提到 33+，否则拿不到 Android 13 的相册能力。

## 三、方法改名

| 0.5.x | 1.0 |
|---|---|
| `showImagePicker(options, cb)` | `pickImage(options)` |
| `asyncShowImagePicker(options)` | `pickImage(options)` |
| `openVideoPicker(options, cb)` | `pickVideo(options)` |
| `openCamera(options, cb)` | `captureImage(options)` |
| `asyncOpenCamera(options)` | `captureImage(options)` |
| — | `captureVideo(options)`（新增） |
| `deleteCache()` | `clearCache()` |
| `removePhotoAtIndex(i)` | **已移除**，见下 |
| `removeAllPhoto()` | **已移除**，见下 |

**callback 形式已全部移除**，只保留 Promise。

## 四、三处语义变更（最需要注意）

### 1. 取消不再是错误

```js
// 0.5.x —— 取消走 catch，和真正的错误混在一起
SYImagePicker.asyncShowImagePicker(opts)
  .then(photos => {})
  .catch(err => { /* err.message === '取消'，也可能是真的出错了 */ });
```

```ts
// 1.0 —— 取消是正常结果，catch 里只剩真正的异常
const res = await pickImage(opts);
if (res.cancelled) return;
res.assets.forEach(...);
```

错误改用有类型的 `error.code`（`PERMISSION_DENIED` / `NO_ACTIVITY` /
`EXPORT_FAILED` / `UNSUPPORTED` / `BUSY`），不再是中文字符串比较。

其中 `BUSY` 是 1.0 新增的：两端都会拒绝并发的原生 UI（相册 / 相机 / 预览）；
Android 的 PictureSelector 另外还有 600ms 防重复点击窗口，窗口内的第二次
启动会被静默丢弃。0.5.x 遇到这种情况 Promise 会永远挂着，1.0 明确 reject。

### 2. 全局选中态已移除

0.5.x 由原生模块单例持有一份选中数组，靠 `removePhotoAtIndex` / `removeAllPhoto`
维护 —— 这与 RN 的数据流心智模型冲突，也是老版本 `removeAllPhoto()` 置空后
再次打开必崩的根因。

1.0 改为显式传回：

```ts
const first = await pickImage();
const second = await pickImage({ selectedAssets: first.assets });  // 回填
// 想清空？不传就是了。想删某一项？自己 filter。
```

### 3. 结果结构变化

```diff
- { width, height, uri, original_uri, type, size, base64 }
+ { uri, originalUri, width, height, size, fileName?, assetId?, base64? }
```

- `original_uri` → `originalUri`（驼峰），并且**默认不再提供** —— 见下
- `type` 已移除（原本仅 Android，且恒为 `"image"`）
- **`base64` 不再带 `data:image/jpeg;base64,` 前缀**，需要的话请自行拼接
- 图片与视频结果拆成两种类型，`VideoAsset` 独有 `duration` / `mime` / `coverUri`
- 新增 `assetId`，用于 `selectedAssets` 回填

### 4. `originalUri` 默认不再提供

0.5.x 无条件返回 `original_uri`。1.0 把它改成**按需**：

```ts
// 默认：结果里没有 originalUri
const res = await pickImage();

// 需要压缩前的原图：显式开启
const res = await pickImage({ keepOriginal: true });
```

原因是它不便宜：保留原图意味着**每张图都要额外完整落盘一份**，9 张就是 9 次
额外 I/O，直接计入用户选完之后的等待时间。绝大多数调用方并不需要它。

类型上 `originalUri` 已改为可选（`originalUri?: string`），TypeScript 会在你
未开启却直接使用时报错，不会静默拿到 undefined。

**不必惋惜**：不压缩（`compress: false`）、用户选择"原图"、以及 GIF 这三种情况下，
`uri` 指向的本来就是原始字节。

### 5. 透明通道现在自动保留

0.5.x 的 `compressFocusAlpha` 默认关闭，意味着**透明 PNG 压缩后透明区域会变黑** ——
那是静默的数据损失。

1.0 改为按**图片实际是否含 alpha** 决定输出格式：有透明通道自动输出 PNG，
不必再记得开开关；不透明的 PNG（截图之类）仍转 JPEG 保住体积收益。

`keepAlpha` 因此退化为"**强制**输出 PNG"的逃生舱，绝大多数调用方不再需要它。

### 6. 相机拍摄不再自动保存到系统相册

0.5.x 的 iOS 相机流程会调 `savePhotoWithImage:location:completion:` 把照片写进
系统相册。1.0 **不再这么做** —— 一个「选择器」库在用户不知情的情况下往相册写东西
是意料之外的副作用，是否入库应该由 App 决定。

影响：`captureImage()` 返回的 uri 位于应用缓存目录，**照片不会出现在系统"照片"里**；
一旦调用方或 `clearCache()` 清掉、或系统在存储紧张时回收临时目录，该文件就没了。

如果你依赖旧行为，请在拿到结果后自行保存，例如用
[@react-native-camera-roll/camera-roll](https://github.com/react-native-cameraroll/react-native-cameraroll)
的 `CameraRoll.save(uri)`，并记得在 `Info.plist` 补 `NSPhotoLibraryAddUsageDescription`。

### 7. 视频默认不再重新编码

0.5.x 固定用 `AVAssetExportPresetHighestQuality`，即**把视频完整转码一遍** ——
一个 1 分钟的 4K 视频要等几十秒。1.0 默认走 passthrough（只复制容器），
**快一个数量级且零画质损失**。

本库本来就不做视频压缩，没有理由转码。若你的服务端只认 H.264 而用户可能拍出
HEVC，用 `pickVideo({ transcode: true })` 恢复旧行为。passthrough 在某些源格式上
失败时，库会**自动回退到转码**，所以通常不必显式开启。

## 五、选项映射表

扁平选项收拢成了 `crop` / `compress` / `video` 三组，**不传该组就是不启用**。

| 0.5.x | 1.0 |
|---|---|
| `imageCount` | `maxCount` |
| `isCamera` | `showCameraButton` |
| `isGif` | `allowGif` |
| `allowPickingOriginalPhoto` | `allowOriginal` |
| `enableBase64` | `includeBase64` |
| `sortAscendingByModificationDate` | `sortOrder: 'asc' \| 'desc'` |
| `showSelectedIndex` | `showSelectionIndex` |
| `isWeChatStyle` | `style: 'wechat'` |
| `isRecordSelected` | 由 `selectedAssets` 取代 |
| `isCrop` | 传 `crop` 对象即启用 |
| `CropW` / `CropH` | `crop.width` / `crop.height` |
| `showCropCircle` | `crop.shape: 'circle'` |
| `circleCropRadius` | 由 `crop.width/height` 推导，已移除 |
| `showCropFrame` / `showCropGrid` | `crop.showFrame` / `crop.showGrid` |
| `freeStyleCropEnabled` | `crop.freeStyle` |
| `rotateEnabled` / `scaleEnabled` | `crop.rotate` / `crop.scale` |
| `compress: false` | `compress: false`（不变） |
| `quality` | `compress.quality`（**现在两端都生效**，见下） |
| `minimumCompressSize` | `compress.minSize`（现在两端都生效） |
| `compressFocusAlpha` | `compress.keepAlpha`（语义已变，见下） |
| —（原本无条件返回） | `keepOriginal`（新增，默认 `false`） |
| `videoMaximumDuration` / `MaxSecond` | `video.maxDuration` |
| `MinSecond` | `video.minDuration` |
| `recordVideoSecond` | `captureVideo({ recordDuration })` |
| `videoCount` | `pickVideo({ maxCount })` |

## 六、行为差异（诚实说明）

- **`style: 'wechat'`**：PictureSelector v3 已移除内置微信主题，1.0 在 Android 上
  落地为"带序号的选择态"，不是像素级复刻。**iOS 上是 no-op**（不是部分主题）。
- **压缩已重写为 auto / manual 双模式**：不传 `compress` 走自动模式（与微信/Luban
  同源的启发式，两端同一套算法）；传对象则进入手动模式，`quality` / `maxWidth` /
  `maxHeight` / `minSize` **两端行为一致**。
  0.5.x 里 `quality` 在 Android 上是被硬替换成 60 的（老 README 写作"安卓无效，
  固定鲁班压缩"），现在它真正生效了。新增 `maxWidth` / `maxHeight`。
  依赖 `io.github.lucksiege:compress`（Luban）已移除。
- **`captureImage` 的裁剪在 iOS 使用系统编辑界面**，`crop.width/height` 不生效。
- 裁剪仅在 `maxCount: 1` 时生效，与 0.5.x 一致。

## 七、顺带修掉的缺陷

以下问题在 0.5.x 中真实存在，1.0 已从结构上规避：

- **Promise 永久挂起**：视频导出失败（iOS 的 failure 回调是空的）、用户拒绝相机权限
  （只弹提示不回调）—— 两条路径都会让调用方永远等下去。1.0 保证每条路径必定结算。
- **UI 卡顿**：Android 的 `new Thread(...).run()` 写成了 `.run()`，线程根本没启动，
  图片解码与 base64 全堵在主线程；iOS 同样把编码留在主队列。
- **误吞其他 SDK 的回调**：Android 的 `onActivityResult` 不过滤 requestCode，
  宿主 App 里任意支付 / 分享 SDK 返回非 OK 结果都会触发本库回调返回"取消"。
- **静默数据损坏**：base64 编码吞掉 IOException 后，仍返回一个由半截数据编成的
  合法字符串。1.0 失败时直接省略该字段。
- **结果顺序错乱**：iOS 用多个异步回调往同一个可变数组追加，顺序与选择顺序不一致。
- **iOS 14 Limited 授权被当成无权限**："仅选中的照片"用户会看到错误提示。
- **裁剪默认值在平板 / 旋转后永远是错的**：`Dimensions` 在模块加载时求值。
- **类型定义与实现不符**：`.d.ts` 声明具名导出，实现是默认导出，两种写法各坏一半。
- iOS 使用了 `PHAsset` 的私有属性 KVC（`valueForKey:@"filename"`），有审核风险。
