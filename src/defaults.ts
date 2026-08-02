/**
 * 默认值与选项归一化。
 *
 * 两条硬规则：
 *
 * 1. 所有默认值用 `satisfies` 反向约束到 `types.ts`，保证类型与默认值不会漂移。
 * 2. **依赖 `Dimensions` 的默认值必须在每次调用时求值。** 老实现在模块加载时
 *    就把裁剪尺寸算死了，于是平板、折叠屏、以及任何一次旋转之后，默认值永远
 *    是错的。
 */

import { Dimensions } from 'react-native';

import type {
  CaptureImageOptions,
  CompressAuto,
  CaptureVideoOptions,
  NativePreviewRequest,
  PreviewOptions,
  CompressOptions,
  CropOptions,
  NativeCaptureImageRequest,
  NativeCaptureVideoRequest,
  NativeCompressConfig,
  NativeCropConfig,
  NativeImageRequest,
  NativeVideoRequest,
  PickImageOptions,
  PickVideoOptions,
} from './types';

/* -------------------------------------------------------------------------- */
/* 默认值                                                                      */
/* -------------------------------------------------------------------------- */

export const IMAGE_DEFAULTS = {
  maxCount: 6,
  minCount: 0,
  maxFileSize: 0,
  minFileSize: 0,
  showCameraButton: true,
  allowGif: false,
  allowWebp: true,
  allowBmp: true,
  allowHeic: true,
  allowOriginal: false,
  includeBase64: false,
  keepOriginal: false,
  showLoading: true,
  sortOrder: 'asc',
  showSelectionIndex: false,
  style: 'default',
} satisfies PickImageOptions;

export const VIDEO_DEFAULTS = {
  maxCount: 1,
  minCount: 0,
  maxFileSize: 0,
  minFileSize: 0,
  showCameraButton: true,
  sortOrder: 'asc',
} satisfies PickVideoOptions;

export const CROP_DEFAULTS = {
  shape: 'rect',
  showFrame: true,
  showGrid: false,
  freeStyle: false,
  rotate: true,
  scale: true,
} satisfies CropOptions;

export const COMPRESS_DEFAULTS = {
  quality: 90,
  minSize: 100,
  keepAlpha: false,
} satisfies CompressOptions;

/**
 * 自动模式固定使用的质量。
 *
 * 取 60 是为了与微信/Luban 的启发式保持一致 —— 该算法的设计前提就是
 * "先大幅降采样，再用较低质量编码"，两者是配套的，单独调高质量并不会更好看。
 */
export const AUTO_COMPRESS_QUALITY = 60;

export const VIDEO_DURATION_DEFAULTS = {
  maxDuration: 180,
  minDuration: 0,
} as const;

export const RECORD_DURATION_DEFAULT = 60;

/** 裁剪框默认边长占屏幕宽度的比例。 */
const CROP_SCREEN_RATIO = 0.6;

/* -------------------------------------------------------------------------- */
/* 工具                                                                        */
/* -------------------------------------------------------------------------- */

/** 每次调用时求值 —— 不要提升到模块作用域。 */
function defaultCropSize(): number {
  const { width } = Dimensions.get('window');
  return Math.floor(width * CROP_SCREEN_RATIO);
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/** 非有限数（NaN / Infinity）一律退回默认值，避免把脏数据传给原生。 */
function positiveInt(value: number | undefined, fallback: number): number {
  if (value === undefined || !Number.isFinite(value)) return fallback;
  return Math.max(1, Math.floor(value));
}

function nonNegativeInt(value: number | undefined, fallback: number): number {
  if (value === undefined || !Number.isFinite(value)) return fallback;
  return Math.max(0, Math.floor(value));
}

/* -------------------------------------------------------------------------- */
/* 归一化                                                                      */
/* -------------------------------------------------------------------------- */

/** 关闭裁剪时的配置。尺寸字段填 0，原生只看 `enabled`。 */
const DISABLED_CROP: NativeCropConfig = {
  enabled: false,
  width: 0,
  height: 0,
  circle: false,
  showFrame: CROP_DEFAULTS.showFrame,
  showGrid: CROP_DEFAULTS.showGrid,
  freeStyle: CROP_DEFAULTS.freeStyle,
  rotate: CROP_DEFAULTS.rotate,
  scale: CROP_DEFAULTS.scale,
};

export function resolveCrop(crop: CropOptions | undefined): NativeCropConfig {
  if (crop === undefined) return { ...DISABLED_CROP };

  // 只有确实要裁剪时才去读 Dimensions。
  const fallbackSize = defaultCropSize();

  return {
    enabled: true,
    width: positiveInt(crop.width, fallbackSize),
    height: positiveInt(crop.height, fallbackSize),
    circle: (crop.shape ?? CROP_DEFAULTS.shape) === 'circle',
    showFrame: crop.showFrame ?? CROP_DEFAULTS.showFrame,
    showGrid: crop.showGrid ?? CROP_DEFAULTS.showGrid,
    freeStyle: crop.freeStyle ?? CROP_DEFAULTS.freeStyle,
    rotate: crop.rotate ?? CROP_DEFAULTS.rotate,
    scale: crop.scale ?? CROP_DEFAULTS.scale,
  };
}

export function resolveCompress(
  compress: false | CompressAuto | CompressOptions | undefined,
): NativeCompressConfig {
  // 不压缩
  if (compress === false) {
    return {
      mode: 'none',
      quality: COMPRESS_DEFAULTS.quality,
      maxWidth: 0,
      maxHeight: 0,
      minSize: COMPRESS_DEFAULTS.minSize,
      keepAlpha: COMPRESS_DEFAULTS.keepAlpha,
    };
  }

  // 不传或显式 'auto' → 自适应。这是默认行为。
  if (compress === undefined || compress === 'auto') {
    return {
      mode: 'auto',
      quality: AUTO_COMPRESS_QUALITY,
      maxWidth: 0,
      maxHeight: 0,
      minSize: COMPRESS_DEFAULTS.minSize,
      keepAlpha: COMPRESS_DEFAULTS.keepAlpha,
    };
  }

  // 手动
  return {
    mode: 'manual',
    quality: clamp(positiveInt(compress.quality, COMPRESS_DEFAULTS.quality), 1, 100),
    maxWidth: nonNegativeInt(compress.maxWidth, 0),
    maxHeight: nonNegativeInt(compress.maxHeight, 0),
    minSize: nonNegativeInt(compress.minSize, COMPRESS_DEFAULTS.minSize),
    keepAlpha: compress.keepAlpha ?? COMPRESS_DEFAULTS.keepAlpha,
  };
}

/**
 * 回填选中态时传给原生的标识。
 *
 * 优先用 `assetId`（iOS 的 PHAsset localIdentifier）—— `uri` 指向的是缓存目录里的
 * 产物文件，iOS 无法由它反查回相册资源。Android 能直接用路径匹配，所以退回 `uri`。
 */
function selectedUris(
  assets: readonly { uri: string; assetId?: string }[] | undefined,
): string[] {
  if (!assets) return [];
  return assets
    .map((a) => a.assetId ?? a.uri)
    .filter((token): token is string => Boolean(token));
}

export function resolvePickImage(
  options: PickImageOptions = {},
): NativeImageRequest {
  return {
    maxCount: positiveInt(options.maxCount, IMAGE_DEFAULTS.maxCount),
    minCount: nonNegativeInt(options.minCount, IMAGE_DEFAULTS.minCount),
    maxFileSize: nonNegativeInt(options.maxFileSize, IMAGE_DEFAULTS.maxFileSize),
    minFileSize: nonNegativeInt(options.minFileSize, IMAGE_DEFAULTS.minFileSize),
    showCameraButton:
      options.showCameraButton ?? IMAGE_DEFAULTS.showCameraButton,
    allowGif: options.allowGif ?? IMAGE_DEFAULTS.allowGif,
    allowWebp: options.allowWebp ?? IMAGE_DEFAULTS.allowWebp,
    allowBmp: options.allowBmp ?? IMAGE_DEFAULTS.allowBmp,
    allowHeic: options.allowHeic ?? IMAGE_DEFAULTS.allowHeic,
    allowOriginal: options.allowOriginal ?? IMAGE_DEFAULTS.allowOriginal,
    includeBase64: options.includeBase64 ?? IMAGE_DEFAULTS.includeBase64,
    keepOriginal: options.keepOriginal ?? IMAGE_DEFAULTS.keepOriginal,
    showLoading: options.showLoading ?? IMAGE_DEFAULTS.showLoading,
    sortAscending: (options.sortOrder ?? IMAGE_DEFAULTS.sortOrder) === 'asc',
    showSelectionIndex:
      options.showSelectionIndex ?? IMAGE_DEFAULTS.showSelectionIndex,
    wechatStyle: (options.style ?? IMAGE_DEFAULTS.style) === 'wechat',
    selectedUris: selectedUris(options.selectedAssets),
    crop: resolveCrop(options.crop),
    compress: resolveCompress(options.compress),
  };
}

export function resolvePickVideo(
  options: PickVideoOptions = {},
): NativeVideoRequest {
  const video = options.video ?? {};
  return {
    transcode: options.transcode ?? false,
    showLoading: options.showLoading ?? true,
    maxCount: positiveInt(options.maxCount, VIDEO_DEFAULTS.maxCount),
    minCount: nonNegativeInt(options.minCount, VIDEO_DEFAULTS.minCount),
    maxFileSize: nonNegativeInt(options.maxFileSize, VIDEO_DEFAULTS.maxFileSize),
    minFileSize: nonNegativeInt(options.minFileSize, VIDEO_DEFAULTS.minFileSize),
    showCameraButton:
      options.showCameraButton ?? VIDEO_DEFAULTS.showCameraButton,
    sortAscending: (options.sortOrder ?? VIDEO_DEFAULTS.sortOrder) === 'asc',
    selectedUris: selectedUris(options.selectedAssets),
    maxDuration: nonNegativeInt(
      video.maxDuration,
      VIDEO_DURATION_DEFAULTS.maxDuration,
    ),
    minDuration: nonNegativeInt(
      video.minDuration,
      VIDEO_DURATION_DEFAULTS.minDuration,
    ),
  };
}

/**
 * 预览请求。
 *
 * 只把 uri 传给原生 —— 预览读的是本地文件，不需要相册资源标识。
 */
export function resolvePreview(
  assets: readonly { uri: string }[] | undefined,
  options: PreviewOptions = {},
): NativePreviewRequest {
  const uris = (assets ?? [])
    .map((a) => a.uri)
    .filter((uri): uri is string => Boolean(uri));

  // index 夹在有效范围内，避免原生越界。
  const index = Math.min(
    Math.max(nonNegativeInt(options.index, 0), 0),
    Math.max(uris.length - 1, 0),
  );

  return { uris, index };
}

export function resolveCaptureImage(
  options: CaptureImageOptions = {},
): NativeCaptureImageRequest {
  return {
    includeBase64: options.includeBase64 ?? IMAGE_DEFAULTS.includeBase64,
    keepOriginal: options.keepOriginal ?? IMAGE_DEFAULTS.keepOriginal,
    crop: resolveCrop(options.crop),
    compress: resolveCompress(options.compress),
  };
}

export function resolveCaptureVideo(
  options: CaptureVideoOptions = {},
): NativeCaptureVideoRequest {
  return {
    recordDuration: positiveInt(
      options.recordDuration,
      RECORD_DURATION_DEFAULT,
    ),
  };
}
