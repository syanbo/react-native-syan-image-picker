/**
 * react-native-syan-image-picker
 *
 * 五个方法，全部返回 Promise：
 * `pickImage` · `pickVideo` · `captureImage` · `captureVideo` · `clearCache`
 *
 * 两条贯穿全库的约定：
 *
 * - **用户取消不是错误。** 取消时 resolve 出 `{ cancelled: true, assets: [] }`，
 *   只有权限被拒、导出失败、`BUSY` 这类真正的异常才会 reject。
 * - **库不持有任何选中态。** 需要"记住上次选择"时把上次的 `assets` 通过
 *   `selectedAssets` 传回即可。
 */

import {
  resolveCaptureImage,
  resolveCaptureVideo,
  resolvePickImage,
  resolvePickVideo,
  resolvePreview,
} from './defaults';
import { getEmitter, SY_PROGRESS_EVENT, SyanNative } from './native';

import type {
  CaptureImageOptions,
  CaptureVideoOptions,
  ImageAsset,
  PickImageOptions,
  PickResult,
  PickVideoOptions,
  PreviewOptions,
  SyanError,
  SyanErrorCode,
  SyanProgress,
  SyanSubscription,
  VideoAsset,
} from './types';

export type {
  Asset,
  CaptureImageOptions,
  CaptureVideoOptions,
  CompressAuto,
  CompressOptions,
  CropOptions,
  CropShape,
  ImageAsset,
  PickerStyle,
  PickImageOptions,
  PickResult,
  PickVideoOptions,
  PreviewOptions,
  SortOrder,
  SyanError,
  SyanErrorCode,
  SyanProgress,
  SyanProgressPhase,
  SyanSubscription,
  VideoAsset,
  VideoDurationOptions,
} from './types';

const ERROR_CODES: readonly SyanErrorCode[] = [
  'PERMISSION_DENIED',
  'NO_ACTIVITY',
  'EXPORT_FAILED',
  'UNSUPPORTED',
  'BUSY',
];

/**
 * 判断一个 catch 到的值是否为本库抛出的、带 {@link SyanErrorCode} 的错误。
 *
 * ```ts
 * try {
 *   await pickImage();
 * } catch (e) {
 *   if (isSyanError(e) && e.code === 'PERMISSION_DENIED') { ... }
 * }
 * ```
 */
export function isSyanError(error: unknown): error is SyanError {
  if (!(error instanceof Error)) return false;
  const code = (error as Partial<SyanError>).code;
  return typeof code === 'string' && ERROR_CODES.includes(code);
}

/**
 * 守住 {@link PickResult} 判别联合的不变式。
 *
 * 即使原生层返回了不规范的数据（缺字段、cancelled 与 assets 自相矛盾），
 * 调用方拿到的也一定是合法的联合值 —— `cancelled: true` 就必然配空数组。
 */
function normalize<T>(raw: PickResult<T> | null | undefined): PickResult<T> {
  if (!raw || raw.cancelled || !Array.isArray(raw.assets)) {
    return { cancelled: true, assets: [] };
  }
  return { cancelled: false, assets: raw.assets };
}

/** 打开相册选择图片。 */
export async function pickImage(
  options?: PickImageOptions,
): Promise<PickResult<ImageAsset>> {
  return normalize(await SyanNative.pickImage(resolvePickImage(options)));
}

/** 打开相册选择视频。 */
export async function pickVideo(
  options?: PickVideoOptions,
): Promise<PickResult<VideoAsset>> {
  return normalize(await SyanNative.pickVideo(resolvePickVideo(options)));
}

/** 打开相机拍照。 */
export async function captureImage(
  options?: CaptureImageOptions,
): Promise<PickResult<ImageAsset>> {
  return normalize(await SyanNative.captureImage(resolveCaptureImage(options)));
}

/** 打开相机录像。 */
export async function captureVideo(
  options?: CaptureVideoOptions,
): Promise<PickResult<VideoAsset>> {
  return normalize(await SyanNative.captureVideo(resolveCaptureVideo(options)));
}

/**
 * 全屏预览一组已有的资源。
 *
 * 纯展示，没有返回值。传入的既可以是本库选出来的 asset，也可以是任何本地文件
 * （只用到 `uri`）。
 *
 * 注意：**预览界面一旦展示就 resolve，不会等用户关闭** —— 两端一致。
 * 预览是独立的界面，关闭时机与调用方的流程无关。
 *
 * ```ts
 * const res = await pickImage();
 * if (!res.cancelled) await openPreview(res.assets, { index: 2 });
 * ```
 */
export async function openPreview(
  assets: readonly { uri: string }[],
  options?: PreviewOptions,
): Promise<void> {
  const request = resolvePreview(assets, options);
  if (request.uris.length === 0) {
    return; // 没东西可看，不必惊动原生
  }
  await SyanNative.openPreview(request);
}

/**
 * 订阅处理进度。
 *
 * **订阅本身就是开关** —— 没有监听者时原生侧完全不发事件，零开销，因此不需要
 * 额外的启用选项。
 *
 * 最主要的用途不是百分比，而是**时机**：promise 从调用那一刻就挂着，但那期间
 * 用户还在相册里挑图；**第一条进度事件的到达才意味着"选择器关了、开始处理了"**。
 *
 * ```ts
 * const sub = addProgressListener(({ completed, total }) => {
 *   setHint(`处理中 ${completed}/${total}`);
 * });
 * // 不再需要时务必移除
 * sub.remove();
 * ```
 *
 * 想自己渲染进度 UI 时，记得同时关掉原生 loading：
 * `pickImage({ showLoading: false })`，否则原生 HUD 会盖住你的界面。
 */
export function addProgressListener(
  listener: (progress: SyanProgress) => void,
): SyanSubscription {
  const subscription = getEmitter().addListener(
    SY_PROGRESS_EVENT,
    (raw: SyanProgress) => {
      // 原生来的数据也做一次形状收口，避免脏值直接进业务代码。
      listener({
        phase: raw?.phase === 'exporting' ? 'exporting' : 'processing',
        completed: Number(raw?.completed) || 0,
        total: Number(raw?.total) || 0,
      });
    },
  );
  return { remove: () => subscription.remove() };
}

/**
 * 清空本库产生的缓存文件（压缩产物、裁剪产物、视频封面）。
 *
 * 这些文件写在应用的缓存目录下，系统也可能自行回收；在批量处理大图后主动调用
 * 可以及时释放空间。
 *
 * **未定义行为：** 在任意 `pick*` / `capture*` / `openPreview` 的 Promise
 * 尚未 settle 时调用。闸门不覆盖清缓存，并发调用可能删掉正在写出的文件，
 * 让随后 resolve 的 `file://` 404，或触发 `EXPORT_FAILED`。请等对应 Promise
 * 完成后再清。
 */
export async function clearCache(): Promise<void> {
  await SyanNative.clearCache();
}

const SYImagePicker = {
  pickImage,
  pickVideo,
  captureImage,
  captureVideo,
  openPreview,
  clearCache,
  addProgressListener,
  isSyanError,
};

export default SYImagePicker;
