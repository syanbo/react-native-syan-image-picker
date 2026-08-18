/**
 * 原生模块访问。
 *
 * 未正确链接时抛出可读的错误，而不是让调用方看到
 * `null is not an object (evaluating 'RNSyanImagePicker.pickImage')`。
 */

import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

import type {
  ImageAsset,
  NativeCaptureImageRequest,
  NativeCaptureVideoRequest,
  NativeImageRequest,
  NativeVideoRequest,
  PickResult,
  VideoAsset,
} from './types';

const LINKING_ERROR =
  `找不到原生模块 'react-native-syan-image-picker'，请确认：\n\n` +
  Platform.select({ ios: "- 已执行 'pod install'\n", default: '' }) +
  '- 安装依赖后已重新构建 App（仅刷新 JS 不够）\n' +
  '- 未在 Expo Go 中运行（本库需要 development build）\n';

/** @internal 原生模块的方法签名。 */
export interface SyanNativeSpec {
  pickImage(request: NativeImageRequest): Promise<PickResult<ImageAsset>>;
  pickVideo(request: NativeVideoRequest): Promise<PickResult<VideoAsset>>;
  captureImage(
    request: NativeCaptureImageRequest,
  ): Promise<PickResult<ImageAsset>>;
  captureVideo(
    request: NativeCaptureVideoRequest,
  ): Promise<PickResult<VideoAsset>>;
  clearCache(): Promise<void>;
  /** NativeEventEmitter 在 RN 0.67 上要求原生模块提供这两个桩方法，否则告警。 */
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

/** @internal 原生发出的进度事件名，两端一致。 */
export const SY_PROGRESS_EVENT = 'RNSyanImagePicker:progress';

/** @internal */
export const SyanNative: SyanNativeSpec =
  NativeModules.RNSyanImagePicker ??
  new Proxy({} as SyanNativeSpec, {
    get(): never {
      throw new Error(LINKING_ERROR);
    },
  });

/**
 * 事件发射器。
 *
 * 延迟创建：没人订阅进度时，连 NativeEventEmitter 都不会实例化。
 * @internal
 */
let emitter: NativeEventEmitter | undefined;

/** @internal */
export function getEmitter(): NativeEventEmitter {
  if (!emitter) {
    emitter = new NativeEventEmitter(
      NativeModules.RNSyanImagePicker as ConstructorParameters<
        typeof NativeEventEmitter
      >[0],
    );
  }
  return emitter;
}
