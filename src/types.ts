/**
 * 公开类型定义。
 *
 * 本文件是选项与结果形状的**唯一事实来源** —— `defaults.ts` 通过 `satisfies`
 * 反向约束到这里，因此默认值不可能与类型漂移。
 */

/* -------------------------------------------------------------------------- */
/* 错误                                                                        */
/* -------------------------------------------------------------------------- */

/**
 * 库会 reject 的错误码。
 *
 * 注意：**用户取消不在此列**。取消是正常结果，通过 `PickResult.cancelled`
 * 表达，不会 reject。
 */
export type SyanErrorCode =
  /** 用户拒绝了相册或相机权限 */
  | 'PERMISSION_DENIED'
  /** Android：当前没有可用的 Activity（App 处于后台或正在重建） */
  | 'NO_ACTIVITY'
  /** 视频导出、图片写盘或压缩失败 */
  | 'EXPORT_FAILED'
  /** 当前平台不支持该能力 */
  | 'UNSUPPORTED'
  /**
   * 上一个选择器、相机或预览展示请求还没结束；Android 也可能是两次启动间隔过短。
   *
   * 两端都会拒绝并发原生 UI。Android 的 PictureSelector 另有 600ms 防重复点击
   * 窗口，窗口内的第二次启动会被它**静默丢弃**。与其让那个 Promise 永远挂着，
   * 不如明确告诉调用方。
   * 通常意味着按钮需要防抖，或在等待期间禁用入口。
   */
  | 'BUSY';

/** 由原生层 reject 的错误，`code` 为 {@link SyanErrorCode} 之一。 */
export interface SyanError extends Error {
  code: SyanErrorCode;
}

/* -------------------------------------------------------------------------- */
/* 结果                                                                        */
/* -------------------------------------------------------------------------- */

/** 图片与视频共有的字段。 */
export interface Asset {
  /**
   * 本地文件路径，始终以 `file://` 开头。
   *
   * `clearCache()` 或系统回收后失效。对应的 `pick*` / `capture*` / `openPreview`
   * Promise 尚未 settle 时调用 `clearCache` 是未定义行为，见该函数注释。
   */
  uri: string;
  /** 像素宽 */
  width: number;
  /** 像素高 */
  height: number;
  /** 文件大小，单位字节 */
  size: number;
  /** 原始文件名，取不到时为 undefined */
  fileName?: string;
  /**
   * 相册中原始资源的标识（iOS 为 `PHAsset.localIdentifier`）。
   *
   * 存在的意义是让 {@link PickImageOptions.selectedAssets} 能真正回填选中态：
   * 结果里的 `uri` 指向的是缓存目录中的产物文件，iOS 无法由它反查回相册资源。
   * 直接把整个 asset 传回即可，无需关心该字段。
   */
  assetId?: string;
}

export interface ImageAsset extends Asset {
  /**
   * 压缩前的原图路径。
   *
   * **仅在 `keepOriginal: true` 时存在**（两端一致）。保留原图意味着每张图都要
   * 额外落盘一份，直接计入用户的等待时间，因此默认不做。
   *
   * 未开启时不必惋惜：不压缩、选择"原图"、GIF 这几种情况下 `uri` 指向的**本来
   * 就是**原始字节。
   */
  originalUri?: string;
  /**
   * 图片的 base64 编码，**仅** `includeBase64: true` 时存在。
   *
   * 是裸编码，不含 `data:image/jpeg;base64,` 前缀 —— 前缀请按需自行拼接，
   * 库不替调用方猜测 MIME。
   */
  base64?: string;
}

export interface VideoAsset extends Asset {
  /** 时长，单位毫秒 */
  duration: number;
  /** MIME 类型，如 `video/mp4` */
  mime: string;
  /** 自动生成的封面图路径，以 `file://` 开头 */
  coverUri: string;
}

/**
 * 选择结果。
 *
 * 用户取消时 `cancelled` 为 `true` 且 `assets` 为空数组 —— 取消**不会** reject。
 *
 * 注意 `cancelled: false` **也可能配空数组**：iOS 上 `maxFileSize` / `allowGif`
 * 这类限制是在结果返回前剔除的，若选中项全部被剔除，就是"用户确实选了、但一个
 * 都不符合条件"。因此**不要假设 `!cancelled` 就一定有元素**，
 * `res.assets[0]` 之前请先判空。
 *
 * ```ts
 * const res = await pickImage();
 * if (res.cancelled) return;
 * res.assets.forEach((a) => console.log(a.uri));
 * ```
 */
export type PickResult<T> =
  | { cancelled: true; assets: [] }
  | { cancelled: false; assets: T[] };

/* -------------------------------------------------------------------------- */
/* 选项                                                                        */
/* -------------------------------------------------------------------------- */

export type CropShape = 'rect' | 'circle';
export type SortOrder = 'asc' | 'desc';
/**
 * 界面风格。
 *
 * `'wechat'` 在 Android 上是带序号的选择态；**iOS 是 no-op**（不是部分主题）。
 */
export type PickerStyle = 'default' | 'wechat';

/**
 * 裁剪配置。**不传 `crop` 就是不裁剪** —— 没有单独的开关字段。
 *
 * 裁剪仅在单选（`maxCount: 1`）时生效；多选时该配置会被忽略。
 */
export interface CropOptions {
  /**
   * 裁剪框宽度，默认为屏幕宽度的 60%（每次调用时计算）。
   *
   * 注意：`width` / `height` 决定的是**裁剪框的宽高比与 UI 尺寸**，
   * **不会**限制输出图片的分辨率 —— 成图仍按原图分辨率裁出。
   * 需要缩放到指定像素请自行处理。
   */
  width?: number;
  /** 裁剪框高度，默认为屏幕宽度的 60%（每次调用时计算）。语义同 {@link width} */
  height?: number;
  /** 裁剪框形状，默认 `'rect'`。`'circle'` 时半径取 `min(width, height) / 2` */
  shape?: CropShape;
  /** 是否显示裁剪边框，默认 `true` */
  showFrame?: boolean;
  /** 是否显示裁剪网格，默认 `false` */
  showGrid?: boolean;
  /** 裁剪框是否可自由拖拽改变比例，默认 `false`。**仅 Android** */
  freeStyle?: boolean;
  /** 是否允许旋转图片，默认 `true`。**仅 Android** */
  rotate?: boolean;
  /** 是否允许缩放图片，默认 `true`。**仅 Android** */
  scale?: boolean;
}

/**
 * 手动压缩配置。
 *
 * 三种取值形态：
 * - 不传 → **自动模式**（等价于 `'auto'`）
 * - `'auto'` → 自适应：按图片尺寸与长宽比自动选择降采样倍率，质量固定 60
 * - `false` → 完全不压缩
 * - 传本对象 → 手动模式，下列参数**两端行为一致**
 */
export interface CompressOptions {
  /** JPEG 压缩质量，1–100，默认 90。**两端一致** */
  quality?: number;
  /**
   * 输出的最大宽度（像素）。与 {@link maxHeight} 一起构成一个**边界框**，
   * 图片按原比例缩放到刚好放得进去为止。不传表示不限制。
   */
  maxWidth?: number;
  /** 输出的最大高度（像素），语义见 {@link maxWidth} */
  maxHeight?: number;
  /**
   * 源文件小于该大小时直接跳过压缩，单位 KB，默认 100。
   *
   * 避免把本来就很小的图重新编码 —— 那往往反而更大。自动模式同样遵守该阈值。
   */
  minSize?: number;
  /**
   * 强制输出 PNG，默认 `false`。
   *
   * **通常不需要动它** —— 带透明通道的图片会**自动**以 PNG 输出，透明不会丢失。
   * 这个开关只用于"明明没有透明通道也要 PNG"的场景（例如后端只收 PNG），
   * 代价是体积会明显变大。
   */
  keepAlpha?: boolean;
}

/**
 * 自动压缩。
 *
 * 采用与微信/Luban 同源的启发式：按长边与长宽比挑选降采样倍率（倍率取 2 的幂），
 * 再以质量 60 编码。**两端跑的是同一套算法，输出像素尺寸完全一致**，
 * 受编码器实现差异影响，文件大小可能有约 ±15% 的出入。
 */
export type CompressAuto = 'auto';

/**
 * 视频时长限制，单位**秒**。
 *
 * 平台差异：Android 在选择界面内直接过滤，不满足条件的视频无法选中；
 * iOS 的 TZImagePickerController 不具备按时长筛选的能力，因此改为在结果返回前
 * 剔除 —— 用户可以选中，但不会出现在 `assets` 里。
 */
export interface VideoDurationOptions {
  /** 可选视频的最大时长，默认 180。传 0 表示不限制 */
  maxDuration?: number;
  /** 可选视频的最小时长，默认 0 */
  minDuration?: number;
}

export interface PickImageOptions {
  /** 最多可选张数，默认 6 */
  maxCount?: number;
  /** 最少必须选够几张才能完成，默认 0（不限制） */
  minCount?: number;
  /**
   * 可选文件的大小上限，单位 KB。不传或 0 表示不限制。
   *
   * 平台差异：Android 在选择界面内直接过滤，超限的选不了；iOS 的
   * TZImagePickerController 不支持按大小筛选，改为**在结果返回前剔除** ——
   * 用户可以选中，但不会出现在 `assets` 里（与 `video.maxDuration` 同一模式）。
   */
  maxFileSize?: number;
  /** 可选文件的大小下限，单位 KB，见 {@link maxFileSize} */
  minFileSize?: number;
  /** 是否在相册内显示拍照入口，默认 `true` */
  showCameraButton?: boolean;
  /**
   * 是否允许选择 GIF，默认 `false`。
   *
   * 平台差异：Android 在查询层过滤，GIF **根本不出现在列表里**；
   * iOS 的 TZImagePickerController 做不到隐藏（它的 `allowPickingGif` 为 NO 时
   * 只是"把 GIF 当作普通图片"），因此改为**在结果返回前剔除** —— 用户能选中，
   * 但不会出现在 `assets` 里。与 `maxFileSize` 是同一种处理方式。
   */
  allowGif?: boolean;
  /** 是否允许选择 WebP，默认 `true`。**仅 Android** */
  allowWebp?: boolean;
  /** 是否允许选择 BMP，默认 `true`。**仅 Android** */
  allowBmp?: boolean;
  /**
   * 是否允许选择 HEIC / HEIF，默认 `true`。**仅 Android**
   *
   * iOS 没有对应能力，但通常也不需要：本库默认会把图片重编码为 JPEG，
   * 只有选择"原图"、`compress: false` 或 GIF 时才透传原始字节。
   */
  allowHeic?: boolean;
  /** 是否显示"原图"选项，默认 `false` */
  allowOriginal?: boolean;
  /** 是否返回 base64 编码，默认 `false`。大图开启会显著增加内存与耗时 */
  includeBase64?: boolean;
  /**
   * 是否额外保留一份压缩前的原图，默认 `false`。
   *
   * 开启后结果里才有 {@link ImageAsset.originalUri}。代价是每张图多一次完整写盘 ——
   * 9 张就是 9 次额外 I/O，会明显拉长选完之后的等待，所以默认关闭。
   */
  keepOriginal?: boolean;
  /** 按修改时间排序，默认 `'asc'` */
  sortOrder?: SortOrder;
  /** 是否在缩略图上显示选中序号，默认 `false` */
  showSelectionIndex?: boolean;
  /**
   * 界面风格，默认 `'default'`。
   *
   * `'wechat'`：**仅 Android** 落地为带序号的选择态；**iOS 是 no-op**
   * （选项会被解析，但没有任何读取方，不是「部分主题」）。
   */
  style?: PickerStyle;
  /**
   * 回填上次的选择结果，这些项会以选中态打开。
   *
   * 本库**不持有任何全局选中态** —— 需要"记住上次选择"时，请把上次的
   * `result.assets` 原样传回。
   */
  selectedAssets?: ImageAsset[];
  /** 裁剪配置，不传则不裁剪 */
  crop?: CropOptions;
  /** 压缩配置，传 `false` 则不压缩 */
  compress?: false | CompressAuto | CompressOptions;
  /**
   * 处理期间是否显示原生 loading，默认 `true`。**仅 iOS**
   *
   * 选完之后还有压缩、编码、写盘等工作要做。开启时选择器会**停在原地转圈**，
   * 处理完再退出；关闭则立刻退出，处理在后台静默进行 —— 那期间用户看到的是
   * 自己的 App 界面毫无反应。
   *
   * Android 由 PictureSelector 自己在压缩阶段显示 loading，本选项不适用。
   *
   * 只有当你想**自己渲染进度 UI** 时才需要关掉它。
   */
  showLoading?: boolean;
}

export interface PickVideoOptions {
  /** 最多可选个数，默认 1 */
  maxCount?: number;
  /** 最少必须选够几个才能完成，默认 0（不限制） */
  minCount?: number;
  /** 可选文件的大小上限，单位 KB，见 {@link PickImageOptions.maxFileSize} */
  maxFileSize?: number;
  /** 可选文件的大小下限，单位 KB */
  minFileSize?: number;
  /** 是否在相册内显示录像入口，默认 `true` */
  showCameraButton?: boolean;
  /** 按修改时间排序，默认 `'asc'` */
  sortOrder?: SortOrder;
  /** 回填上次的选择结果，见 {@link PickImageOptions.selectedAssets} */
  selectedAssets?: VideoAsset[];
  /** 时长限制 */
  video?: VideoDurationOptions;
  /**
   * 是否重新编码视频，默认 `false`。**仅 iOS**
   *
   * 默认走 passthrough —— 只复制容器、不重新编码，**快一个数量级且零画质损失**。
   * 本库本来就不做视频压缩，没有理由把视频完整转码一遍。
   *
   * 只有当你的服务端只认 H.264、而用户可能拍出 HEVC 时才需要开。
   * 注意 passthrough 若在某些源格式上失败，库会**自动回退到转码**，所以通常
   * 不必显式开启。
   */
  transcode?: boolean;
  /**
   * 处理期间是否显示原生 loading，默认 `true`。**仅 iOS**
   * 见 {@link PickImageOptions.showLoading}
   */
  showLoading?: boolean;
}

export interface CaptureImageOptions {
  /** 是否返回 base64 编码，默认 `false` */
  includeBase64?: boolean;
  /** 是否保留压缩前的原图，默认 `false`。见 {@link PickImageOptions.keepOriginal} */
  keepOriginal?: boolean;
  /** 裁剪配置，不传则不裁剪 */
  crop?: CropOptions;
  /** 压缩配置，传 `false` 则不压缩 */
  compress?: false | CompressAuto | CompressOptions;
}

/** {@link openPreview} 的选项。 */
export interface PreviewOptions {
  /** 初始展示第几项，默认 0 */
  index?: number;
}

export interface CaptureVideoOptions {
  /** 最长录制时长，单位秒，默认 60 */
  recordDuration?: number;
}

/* -------------------------------------------------------------------------- */
/* 进度                                                                        */
/* -------------------------------------------------------------------------- */

/**
 * 处理阶段。
 *
 * - `processing` —— 压缩、编码、写盘
 * - `exporting` —— 视频导出
 */
export type SyanProgressPhase = 'processing' | 'exporting';

/**
 * 处理进度。
 *
 * **第一条进度事件的到达本身就意味着"选择器已关闭、开始处理了"** —— 在这之前
 * promise 虽然挂着，但用户还在相册里挑图。这是这套事件最主要的用途。
 */
export interface SyanProgress {
  phase: SyanProgressPhase;
  /** 已完成的项数 */
  completed: number;
  /** 总项数 */
  total: number;
}

/** {@link addProgressListener} 的返回值，务必在不需要时调用 `remove()`。 */
export interface SyanSubscription {
  remove(): void;
}

/* -------------------------------------------------------------------------- */
/* 缓存                                                                        */
/* -------------------------------------------------------------------------- */

/*
 * `clearCache()` 契约：在任意 `pick*` / `capture*` / `openPreview` 对应的
 * Promise **尚未 settle** 时调用是**未定义行为**。可能删掉正在写出的缓存文件，
 * 让随后 resolve 的 `file://` 404，或触发 `EXPORT_FAILED`。闸门不覆盖清缓存。
 * 请等对应 Promise 完成后再清。
 */

/* -------------------------------------------------------------------------- */
/* 传给原生层的线格式（内部）                                                    */
/* -------------------------------------------------------------------------- */

/**
 * 以下类型描述真正跨桥传给原生的数据。
 *
 * 关键约定：**每个字段都是必填的**。JS 层负责把用户的稀疏选项补全成完整对象，
 * 原生层因此永远不会读到缺失的 key。老实现在这里踩过坑 —— 原生用无保护的
 * `getInt()` 读取，一旦调用方绕过 JS 直接调用原生就会崩。
 *
 * @internal
 */
export interface NativeCropConfig {
  enabled: boolean;
  width: number;
  height: number;
  circle: boolean;
  showFrame: boolean;
  showGrid: boolean;
  freeStyle: boolean;
  rotate: boolean;
  scale: boolean;
}

/** @internal 压缩模式：不压缩 / 自适应 / 手动 */
export type NativeCompressMode = 'none' | 'auto' | 'manual';

/** @internal */
export interface NativeCompressConfig {
  mode: NativeCompressMode;
  /** 手动模式下生效；自动模式固定为 60（仍然下发，便于原生层统一取值） */
  quality: number;
  /** 0 表示不限制 */
  maxWidth: number;
  /** 0 表示不限制 */
  maxHeight: number;
  /** KB */
  minSize: number;
  keepAlpha: boolean;
}

/** @internal */
export interface NativeImageRequest {
  keepOriginal: boolean;
  allowWebp: boolean;
  allowBmp: boolean;
  allowHeic: boolean;
  showLoading: boolean;
  maxCount: number;
  minCount: number;
  maxFileSize: number;
  minFileSize: number;
  showCameraButton: boolean;
  allowGif: boolean;
  allowOriginal: boolean;
  includeBase64: boolean;
  sortAscending: boolean;
  showSelectionIndex: boolean;
  wechatStyle: boolean;
  selectedUris: string[];
  crop: NativeCropConfig;
  compress: NativeCompressConfig;
}

/** @internal */
export interface NativeVideoRequest {
  transcode: boolean;
  showLoading: boolean;
  maxCount: number;
  minCount: number;
  maxFileSize: number;
  minFileSize: number;
  showCameraButton: boolean;
  sortAscending: boolean;
  selectedUris: string[];
  maxDuration: number;
  minDuration: number;
}

/** @internal */
export interface NativePreviewRequest {
  uris: string[];
  index: number;
}

/** @internal */
export interface NativeCaptureImageRequest {
  includeBase64: boolean;
  keepOriginal: boolean;
  crop: NativeCropConfig;
  compress: NativeCompressConfig;
}

/** @internal */
export interface NativeCaptureVideoRequest {
  recordDuration: number;
}
