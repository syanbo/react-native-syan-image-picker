# 手工验收清单

这类库的核心路径是**跨进程的系统 UI**（相册、相机、权限弹窗）。Detox 之类的
e2e 方案驱动不了它们，只会得到一套持续 flake、最终被禁用的测试。所以这份清单
就是本库真正的测试套件 —— 任何改动 `ios/` 或 `android/` 的 PR 都必须跑一遍。

自动化覆盖的范围（CI 全跑）：
- JS 选项归一化 —— `npx jest`
- 压缩算法两端一致性 —— Android `CompressPlanTest` / iOS `ios/tests/plan_test.m`，
  读同一份 `__fixtures__/compress-plan.json`
- iOS 编解码正确性 —— `ios/tests/codec_test.m`
- 两端编译（最新 RN 与 RN 0.67.5 下限）

**Android 的编解码路径没有自动化覆盖**（不在 CI 跑模拟器），见下方专项。

## 设备矩阵

| 平台 | 版本 | 为什么必须覆盖 |
|---|---|---|
| Android | 12 | 旧存储权限模型（`READ_EXTERNAL_STORAGE`） |
| Android | 13 | 分类媒体权限（`READ_MEDIA_IMAGES`）的分水岭 |
| Android | 14 | **"仅选择部分照片"**（`READ_MEDIA_VISUAL_USER_SELECTED`） |
| iOS | 16 | 完整授权基线 |
| iOS | 17 | **Limited（"仅选中的照片"）授权** |
| iOS | 任意 | 拒绝授权后的表现 |

## 基础功能（每个平台各跑一遍）

- [ ] `pickImage()` 多选，结果数量正确
- [ ] `pickImage({ maxCount: 1 })` 单选
- [ ] `pickImage({ maxCount: 1, crop: { width: 300, height: 300 } })` 矩形裁剪
- [ ] `crop.shape: 'circle'` 圆形裁剪
- [ ] `pickImage({ includeBase64: true })`，base64 能被解码回原图
- [ ] `pickImage({ allowGif: true })` 选中 GIF
- [ ] `pickImage({ allowGif: false })`：Android 列表里**看不到** GIF；
      iOS 能选中但**不出现在结果里**（两端表现不同，属已知差异）
- [ ] Android `allowHeic: false`：华为/iPhone 导入的 HEIC 不出现在列表里
- [ ] `pickVideo()`，`duration` / `mime` / `coverUri` 均正确
- [ ] `captureImage()` 拍照
- [ ] `captureVideo({ recordDuration: 10 })` 录像，超时自动停止
- [ ] `clearCache()` 后缓存目录确实被清空
- [ ] `pickImage({ minCount: 3 })`：选不够 3 张时"完成"按钮不可用
- [ ] `pickImage({ maxFileSize: 500 })`：Android 超限的图**选不了**；
      iOS 能选中但**不出现在结果里**（两端行为不同，见 README 平台差异表）
- [ ] `openPreview(assets, { index: 1 })`：全屏预览，从第 2 项开始，可左右滑
- [ ] **GIF 不被压缩**：选一张 GIF，结果文件仍是 GIF 且动画完好
      （Android 曾因换掉 Luban 丢过这个行为）

## 压缩

> **已自动化的部分不必手测**：
> - 倍率算法与输出尺寸 → 两端各自读同一份 `__fixtures__/compress-plan.json`
>   （Android `CompressPlanTest`，iOS `ios/tests/plan_test.m`），CI 每次都跑
> - iOS 的编解码（降采样尺寸、EXIF 方向、alpha、质量与体积关系）
>   → `ios/tests/codec_test.m`
>
> **下面这些自动化覆盖不到**，必须真机验证：

- [ ] `pickImage()`（自动模式）：4032×3024 的原图应输出 2016×1512
- [ ] `pickImage({ compress: false })`：产物与相册原图**字节完全一致**
- [ ] `pickImage({ compress: { maxWidth: 1000 } })`：长边不超过 1000
- [ ] `pickImage({ compress: { quality: 30 } })` 与 `quality: 95` 体积差异明显
      （0.5.x 时代该参数在 Android 上是被写死为 60 的，现在两端都真正生效）
- [ ] 选一张小于 100KB 的图，自动模式下应**跳过压缩**（minSize 生效）

**Android 编解码专项**（本项目**刻意不在 CI 跑模拟器**，故这一块完全靠手测）：

- [ ] **竖拍照片压缩后方向正确**（EXIF 旋转 —— 自研引擎后新补的逻辑，最易回归）
- [ ] **带透明通道的 PNG 用默认参数**（不传 keepAlpha）选入 → 输出仍是 PNG、
      透明区域**没有变黑**。这是曾经的静默数据损失点，两端都要验
- [ ] 不透明的 PNG（截图）用默认参数 → 输出 JPEG，体积明显小于源文件
- [ ] 不透明图 + `keepAlpha: true` → 强制输出 PNG
- [ ] 连选 9 张 12MP 大图压缩，无 OOM、无 Bitmap 泄漏（Profiler 观察）
- [ ] 压缩产物落在 `syan-image-picker/` 缓存目录下，`clearCache()` 能清掉

- [ ] **两端对拍**：同一张图在 iOS 与 Android 的自动模式下输出**像素尺寸相同**，
      文件大小差异在 ±15% 以内（见 docs/compress-parity.md）

## 回归专项

每一条都对应 0.5.x 中一个真实存在的缺陷，**这些是最容易复发的地方**。

### 绝不能挂起
- [ ] 用户取消 → resolve `{ cancelled: true }`，**不 reject**
- [ ] 拒绝相册权限 → reject `PERMISSION_DENIED`，**不是无限等待**
- [ ] 拒绝相机权限 → reject `PERMISSION_DENIED`
- [ ] 视频导出失败（挑一个超大 4K 视频，或把磁盘塞满）→ reject `EXPORT_FAILED`
- [ ] 选择器打开期间把 App 切到后台再回来 → 不会卡在半路

### 状态隔离
- [ ] Android：在宿主 App 内触发**其他** SDK 的 Activity 并取消它
      → 本库**不得**收到任何回调
- [ ] 连续快速点击两次触发选择 → 第二次应 reject `BUSY`，**不得**悬空
- [ ] Android：在权限弹窗中点拒绝 → reject `PERMISSION_DENIED`
      **且选择器界面自动关闭**（不能停留在原生 UI 上）
- [ ] iOS：选择器与相机均以**全屏**呈现，裁剪框位置正确（iPad 上尤其要看）

### 处理期间的 loading 与进度（本轮新增，autoDismiss=NO 是高风险改动）
- [ ] iOS 默认：选完之后**选择器停在原地转圈**，处理完才退出（不是先消失再卡住）
- [ ] iOS `showLoading: false`：选择器立刻退出，处理在后台进行
- [ ] **取消也必须能关闭选择器** —— autoDismiss=NO 之后取消不再自动 dismiss，
      这是最容易漏的一条，务必验证
- [ ] 导出失败（磁盘塞满 / 超大视频）时选择器**也要能关掉**，不能卡在屏幕上
- [ ] 订阅 `addProgressListener` 后能收到 `completed/total` 递增；`remove()` 后不再收到
- [ ] **`showLoading: false` 时 promise 必须正常结算**（曾因重复 dismiss 永久挂起）
- [ ] **Android 开启裁剪 / 相机拍摄后压缩能正常完成**（曾因回调 key 用了
      `uri.toString()` 与队列 key 不匹配，选择器永久 loading 且此后全部 BUSY）
- [ ] **`allowGif: true` 时点 GIF，完成按钮有响应**（曾因未开
      `allowPickingMultipleVideo` 被路由到无回调的 GIF 预览页而卡死）
- [ ] **单选 + crop 时网格上没有勾选框**，只能经预览页裁剪后完成（裁剪不可绕过）
- [ ] 小于 100KB 的图 + crop：返回的必须是**裁剪后**的图，不是原图
- [ ] iOS 自动模式对 4032×3024 输出 2016×1512（曾因按 828px 预览图算而完全不降采样）
- [ ] Android EXIF 方向 6 的照片 + `maxHeight: 1000`：输出高度不超过 1000
- [ ] 不订阅时功能一切正常（原生不发事件）
- [ ] 视频默认 passthrough：选一个大视频，导出应是**秒级**而非几十秒；
      `transcode: true` 时明显变慢但仍成功
- [ ] `keepOriginal: false`（默认）结果里**没有** `originalUri`；开启后才有
- [ ] 先 `pickImage({ compress: { quality: 10 } })`，再 `pickVideo()`
      → 视频封面质量正常（老实现会读到上一次的残留选项）

### 性能与内存
- [ ] 一次选 9 张 12MP 图片 + `includeBase64: true`
      → 无 ANR、无 OOM
- [ ] 同上，用 Profiler 确认**解码不在主线程**

### 数据正确性
- [ ] 图文混选，结果顺序与**选择顺序**一致
- [ ] `size` 与实际文件字节数一致
- [ ] 竖屏拍摄的视频，`width` / `height` 不是转置的
- [ ] 平板或折叠屏上不传 `crop.width` → 裁剪框按当前屏宽计算
- [ ] 横竖屏切换后再打开 → 裁剪框尺寸跟着变（不是 import 时冻结的值）

### 选中态回填
- [ ] `pickImage({ selectedAssets: previous.assets })` → 已选项正确高亮
- [ ] iOS：确认走的是 `assetId`（`uri` 指向缓存产物，反查不回相册）

## 权限与清单

- [ ] 检查合并后的清单 `app/build/outputs/logs/manifest-merger-*-report.txt`：
      注入的权限应为 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO`、
      `READ_MEDIA_VISUAL_USER_SELECTED`，且 `READ_EXTERNAL_STORAGE`
      带 `android:maxSdkVersion="32"`
- [ ] 确认 `CAMERA` **已**注入（PictureSelector 拉起相机前会检查它，缺了拍摄功能全废）
- [ ] 宿主用 `tools:node="remove"` 移除 `CAMERA` 后，纯相册流程仍可用
- [ ] Android 14 授予"仅选择部分照片"后，相册能正常显示已授权的那部分
- [ ] iOS 17 Limited 授权下能正常选图，**不会**弹出错误的"无权限"提示

## 构建

- [ ] Android RN 0.67.5（AGP 7.x / Gradle 7.x / JDK 11）构建通过
- [ ] Android 最新 RN（AGP 8.x / Gradle 8.x / JDK 17）构建通过
- [ ] `pod install` 干净通过，iOS 构建无新增告警
- [ ] release 构建开启 R8 后，缩略图正常显示（验证 `consumer-rules.pro`）
- [ ] `npm pack --dry-run` 产物中包含 `lib/ src/ ios/ android/ podspec`，
      且**不含** `example*/`
