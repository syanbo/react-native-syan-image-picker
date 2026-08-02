/**
 * 选项归一化的单元测试。
 *
 * 这是本库唯一的纯逻辑，也是最容易在重构中被悄悄改坏的部分，值得测。
 * 跨进程的相册/相机/权限 UI 不在自动化测试范围内，由 docs/QA-CHECKLIST.md 覆盖。
 */

let mockScreenWidth = 400;

jest.mock('react-native', () => ({
  Dimensions: {
    get: () => ({ width: mockScreenWidth, height: 800 }),
  },
  Platform: { select: (obj: Record<string, unknown>) => obj.default },
  NativeModules: {},
}));

import {
  resolveCaptureVideo,
  resolveCompress,
  resolveCrop,
  resolvePickImage,
  resolvePickVideo,
} from '../src/defaults';

beforeEach(() => {
  mockScreenWidth = 400;
});

describe('resolveCrop', () => {
  it('不传 crop 时关闭裁剪', () => {
    expect(resolveCrop(undefined).enabled).toBe(false);
  });

  it('传了 crop 就启用，并按屏幕宽度 60% 给默认尺寸', () => {
    const crop = resolveCrop({});
    expect(crop.enabled).toBe(true);
    expect(crop.width).toBe(240); // 400 * 0.6
    expect(crop.height).toBe(240);
  });

  it('显式尺寸优先于屏幕推导值', () => {
    expect(resolveCrop({ width: 300, height: 150 })).toMatchObject({
      width: 300,
      height: 150,
    });
  });

  it('shape 映射为 circle 布尔值', () => {
    expect(resolveCrop({ shape: 'circle' }).circle).toBe(true);
    expect(resolveCrop({ shape: 'rect' }).circle).toBe(false);
    expect(resolveCrop({}).circle).toBe(false);
  });

  it('每次调用都重新读取 Dimensions —— 旋转/折叠屏后默认值必须跟着变', () => {
    expect(resolveCrop({}).width).toBe(240);

    mockScreenWidth = 800; // 模拟转到横屏
    expect(resolveCrop({}).width).toBe(480);
  });

  it('关闭裁剪时不返回被污染的尺寸', () => {
    const crop = resolveCrop(undefined);
    expect(crop.width).toBe(0);
    expect(crop.height).toBe(0);
  });
});

describe('resolveCompress', () => {
  it('不传时走自动模式（这是默认行为）', () => {
    expect(resolveCompress(undefined)).toMatchObject({
      mode: 'auto',
      quality: 60,
      minSize: 100,
    });
  });

  it("显式 'auto' 与不传等价", () => {
    expect(resolveCompress('auto')).toEqual(resolveCompress(undefined));
  });

  it('传 false 时关闭压缩', () => {
    expect(resolveCompress(false).mode).toBe('none');
  });

  it('传对象时进入手动模式，质量默认 90', () => {
    expect(resolveCompress({})).toMatchObject({
      mode: 'manual',
      quality: 90,
      maxWidth: 0,
      maxHeight: 0,
    });
  });

  it('手动模式的 quality 被夹在 1..100', () => {
    expect(resolveCompress({ quality: 500 }).quality).toBe(100);
    expect(resolveCompress({ quality: 0 }).quality).toBe(1);
    expect(resolveCompress({ quality: 55 }).quality).toBe(55);
  });

  it('maxWidth/maxHeight 不传即 0（表示不限制）', () => {
    const cfg = resolveCompress({ maxWidth: 1920 });
    expect(cfg.maxWidth).toBe(1920);
    expect(cfg.maxHeight).toBe(0);
  });

  it('minSize 三种模式下都有值 —— 两端都要遵守该阈值', () => {
    expect(resolveCompress('auto').minSize).toBe(100);
    expect(resolveCompress(false).minSize).toBe(100);
    expect(resolveCompress({ minSize: 50 }).minSize).toBe(50);
  });

  it('非有限数退回默认值，不把 NaN 传给原生', () => {
    expect(resolveCompress({ quality: NaN }).quality).toBe(90);
    expect(resolveCompress({ minSize: Infinity }).minSize).toBe(100);
  });
});

describe('resolvePickImage', () => {
  it('无参数时产出完整的默认请求', () => {
    expect(resolvePickImage()).toMatchObject({
      maxCount: 6,
      showCameraButton: true,
      allowGif: false,
      allowOriginal: false,
      includeBase64: false,
      sortAscending: true,
      showSelectionIndex: false,
      wechatStyle: false,
      selectedUris: [],
    });
  });

  it('每个字段都有值 —— 原生层永远读不到缺失的 key', () => {
    const req = resolvePickImage({ maxCount: 3 }) as unknown as Record<
      string,
      unknown
    >;
    for (const [key, value] of Object.entries(req)) {
      expect([key, value]).not.toContain(undefined);
    }
  });

  it('格式过滤默认值：GIF 默认排除，其余默认允许', () => {
    const req = resolvePickImage();
    // 与 PictureSelector 的默认值一致：isGif=false，isWebp/isBmp/isHeic=true
    expect(req.allowGif).toBe(false);
    expect(req.allowWebp).toBe(true);
    expect(req.allowBmp).toBe(true);
    expect(req.allowHeic).toBe(true);
  });

  it('sortOrder 与 style 由枚举映射为布尔', () => {
    expect(resolvePickImage({ sortOrder: 'desc' }).sortAscending).toBe(false);
    expect(resolvePickImage({ style: 'wechat' }).wechatStyle).toBe(true);
  });

  it('selectedAssets 只把 uri 传给原生', () => {
    const req = resolvePickImage({
      selectedAssets: [
        { uri: 'file://a.jpg', originalUri: 'file://a.jpg', width: 1, height: 1, size: 1 },
        { uri: 'file://b.jpg', originalUri: 'file://b.jpg', width: 1, height: 1, size: 1 },
      ],
    });
    expect(req.selectedUris).toEqual(['file://a.jpg', 'file://b.jpg']);
  });

  it('回填选中态时优先用 assetId —— uri 指向缓存产物，iOS 反查不回相册', () => {
    const req = resolvePickImage({
      selectedAssets: [
        {
          uri: 'file://cache/a.jpg',
          originalUri: 'file://cache/a.jpg',
          assetId: 'ABC-123/L0/001',
          width: 1,
          height: 1,
          size: 1,
        },
        // 没有 assetId 时退回 uri（Android 可直接按路径匹配）
        {
          uri: 'file://cache/b.jpg',
          originalUri: 'file://cache/b.jpg',
          width: 1,
          height: 1,
          size: 1,
        },
      ],
    });
    expect(req.selectedUris).toEqual(['ABC-123/L0/001', 'file://cache/b.jpg']);
  });

  it('maxCount 至少为 1', () => {
    expect(resolvePickImage({ maxCount: 0 }).maxCount).toBe(1);
    expect(resolvePickImage({ maxCount: -5 }).maxCount).toBe(1);
  });
});

describe('resolvePickVideo', () => {
  it('默认单选，时长限制为 0..180 秒', () => {
    expect(resolvePickVideo()).toMatchObject({
      maxCount: 1,
      minDuration: 0,
      maxDuration: 180,
    });
  });

  it('接受嵌套的 video 时长配置', () => {
    const req = resolvePickVideo({ video: { maxDuration: 30, minDuration: 5 } });
    expect(req).toMatchObject({ maxDuration: 30, minDuration: 5 });
  });
});

describe('resolveCaptureVideo', () => {
  it('默认录制时长 60 秒', () => {
    expect(resolveCaptureVideo().recordDuration).toBe(60);
  });
});
