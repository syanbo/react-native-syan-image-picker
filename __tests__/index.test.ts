/**
 * 公开 API 的契约测试。
 *
 * 重点是两条最容易回归的约定：取消不 reject；结果联合类型的不变式即使原生层
 * 返回脏数据也必须成立。
 */

// 注意：jest.mock 的工厂会被提升到本文件顶部，早于任何 const 初始化，
// 所以 mock 对象必须在工厂内部创建，之后再取引用 —— 否则会读到 TDZ 中的变量。
jest.mock('react-native', () => ({
  NativeEventEmitter: class {
    addListener(name: string, handler: (p: unknown) => void) {
      (globalThis as Record<string, unknown>).__syanHandler = handler;
      (globalThis as Record<string, unknown>).__syanEvent = name;
      return { remove: jest.fn() };
    }
  },
  Dimensions: { get: () => ({ width: 400, height: 800 }) },
  Platform: { select: (obj: Record<string, unknown>) => obj.default },
  NativeModules: {
    RNSyanImagePicker: {
      pickImage: jest.fn(),
      pickVideo: jest.fn(),
      captureImage: jest.fn(),
      captureVideo: jest.fn(),
      clearCache: jest.fn(),
      addListener: jest.fn(),
      removeListeners: jest.fn(),
    },
  },
}));

import { NativeModules } from 'react-native';

const mockNative = NativeModules.RNSyanImagePicker as Record<
  | 'pickImage'
  | 'pickVideo'
  | 'captureImage'
  | 'captureVideo'
  | 'clearCache',
  jest.Mock
>;

import SYImagePicker, {
  addProgressListener,
  captureImage,
  captureVideo,
  clearCache,
  isSyanError,
  pickImage,
  pickVideo,
} from '../src/index';

const anImage = {
  uri: 'file://a.jpg',
  originalUri: 'file://a.jpg',
  width: 100,
  height: 200,
  size: 1234,
};

beforeEach(() => {
  jest.clearAllMocks();
});

describe('导出形态', () => {
  it('具名导出与默认导出都可用', () => {
    expect(typeof pickImage).toBe('function');
    expect(typeof SYImagePicker.pickImage).toBe('function');
    expect(SYImagePicker.pickImage).toBe(pickImage);
  });

  it('公开面恰好是这些，不多不少', () => {
    expect(Object.keys(SYImagePicker).sort()).toEqual([
      'addProgressListener',
      'captureImage',
      'captureVideo',
      'clearCache',
      'isSyanError',
      'pickImage',
      'pickVideo',
    ]);
  });
});

describe('取消不是错误', () => {
  it('取消时 resolve 而不是 reject', async () => {
    mockNative.pickImage.mockResolvedValue({ cancelled: true, assets: [] });

    const res = await pickImage();

    expect(res.cancelled).toBe(true);
    expect(res.assets).toEqual([]);
  });

  it('每个选择方法在取消时都遵循同一形状', async () => {
    mockNative.pickVideo.mockResolvedValue({ cancelled: true, assets: [] });
    mockNative.captureImage.mockResolvedValue({ cancelled: true, assets: [] });
    mockNative.captureVideo.mockResolvedValue({ cancelled: true, assets: [] });

    for (const res of [
      await pickVideo(),
      await captureImage(),
      await captureVideo(),
    ]) {
      expect(res).toEqual({ cancelled: true, assets: [] });
    }
  });
});

describe('结果归一化', () => {
  it('正常选择时透传 assets', async () => {
    mockNative.pickImage.mockResolvedValue({
      cancelled: false,
      assets: [anImage],
    });

    const res = await pickImage();

    expect(res.cancelled).toBe(false);
    expect(res.assets).toEqual([anImage]);
  });

  it('原生返回 null 时降级为取消，而不是抛 TypeError', async () => {
    mockNative.pickImage.mockResolvedValue(null);
    await expect(pickImage()).resolves.toEqual({ cancelled: true, assets: [] });
  });

  it('原生返回自相矛盾的数据时仍守住联合类型不变式', async () => {
    // cancelled 为 true 却带着 assets —— 必须以 cancelled 为准
    mockNative.pickImage.mockResolvedValue({
      cancelled: true,
      assets: [anImage],
    });
    await expect(pickImage()).resolves.toEqual({ cancelled: true, assets: [] });

    // assets 不是数组
    mockNative.pickVideo.mockResolvedValue({ cancelled: false, assets: null });
    await expect(pickVideo()).resolves.toEqual({ cancelled: true, assets: [] });
  });
});

describe('真正的错误仍然 reject', () => {
  it('权限被拒时向上抛出', async () => {
    const err = Object.assign(new Error('用户拒绝了相册权限'), {
      code: 'PERMISSION_DENIED',
    });
    mockNative.pickImage.mockRejectedValue(err);

    await expect(pickImage()).rejects.toThrow('用户拒绝了相册权限');
  });

  it('isSyanError 只认已知错误码', () => {
    expect(
      isSyanError(Object.assign(new Error('x'), { code: 'PERMISSION_DENIED' })),
    ).toBe(true);
    expect(isSyanError(Object.assign(new Error('x'), { code: 'WHATEVER' }))).toBe(
      false,
    );
    expect(isSyanError(new Error('x'))).toBe(false);
    expect(isSyanError('not an error')).toBe(false);
    expect(isSyanError(null)).toBe(false);
  });
});

describe('传给原生的请求', () => {
  it('传的是补全后的请求，而不是用户的稀疏选项', async () => {
    mockNative.pickImage.mockResolvedValue({ cancelled: true, assets: [] });

    await pickImage({ maxCount: 2 });

    const req = mockNative.pickImage.mock.calls[0]![0];
    expect(req.maxCount).toBe(2);
    expect(req.crop.enabled).toBe(false);
    expect(req.compress.mode).toBe('auto');
    expect(req.selectedUris).toEqual([]);
  });

  it('进度事件被收口成合法形状，脏值不会漏进业务代码', () => {
    const seen: unknown[] = [];
    addProgressListener((p) => seen.push(p));

    const emit = (globalThis as Record<string, unknown>).__syanHandler as (
      p: unknown,
    ) => void;

    emit({ phase: 'processing', completed: 3, total: 9 });
    emit({ phase: '乱七八糟', completed: '2', total: null });
    emit(undefined);

    expect(seen).toEqual([
      { phase: 'processing', completed: 3, total: 9 },
      // 未知 phase 收敛为 processing，非数字归零
      { phase: 'processing', completed: 2, total: 0 },
      { phase: 'processing', completed: 0, total: 0 },
    ]);
  });

  it('订阅的事件名与原生一致', () => {
    addProgressListener(() => {});
    expect((globalThis as Record<string, unknown>).__syanEvent).toBe(
      'RNSyanImagePicker:progress',
    );
  });

  it('clearCache 直接透传', async () => {
    mockNative.clearCache.mockResolvedValue(undefined);
    await expect(clearCache()).resolves.toBeUndefined();
    expect(mockNative.clearCache).toHaveBeenCalledTimes(1);
  });
});
