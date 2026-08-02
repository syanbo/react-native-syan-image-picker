# 自动压缩 · 两端一致性真值表

自动模式的降采样算法在两端各有一份实现，**必须逐行对应**：

- Android：`android/src/main/java/com/syanpicker/CompressPlan.kt`
- iOS：`ios/SYCompressPlan.m`

改动任一侧时，请同步另一侧，并用下表对拍。

## 契约

> 自动模式下两端**输出像素尺寸完全一致**；文件大小允许约 ±15% 差异
> （libjpeg 与 Apple 编码器的实现差别，画质无肉眼可见区别）。

尺寸一致的前提是**采样倍率取 2 的幂**。Android 的 `BitmapFactory` 本来就会把
`inSampleSize` 向下取整到 2 的幂，iOS 侧显式对齐了这一点 —— 否则 ImageIO 能用
任意倍率，两端就会算出不同尺寸。

## 这份契约由测试守着，不靠人工

真值表已固化为 **`__fixtures__/compress-plan.json`**，两端读的是**同一个文件**：

| 测试 | 位置 | 何时跑 |
|---|---|---|
| Android 算法一致性 | `android/src/test/.../CompressPlanTest.kt` | 每次 push（纯 JVM，秒级） |
| iOS 算法一致性 | `ios/tests/plan_test.m` | PR + 每周 |
| iOS 编解码正确性 | `ios/tests/codec_test.m` | PR + 每周 |

共用 fixture 是关键 —— 两端各自维护期望值的话，改了一侧只会让那一侧跟着变绿。
实测验证过：把 Kotlin 里的 `LONG_SIDE_SMALL` 从 1664 改成 1600，
`CompressPlanTest` 立刻有两个用例转红。

本地跑：

```sh
./ios/tests/run.sh                                    # iOS 两套
cd example/android && ./gradlew \
  :react-native-syan-image-picker:testDebugUnitTest    # Android
```

**没被自动化覆盖的**：Android 的编解码路径（`BitmapFactory`、EXIF 旋转、alpha）
—— 这些在 JVM 上测不了，本项目又刻意不在 CI 跑模拟器，因此归入
[QA-CHECKLIST.md](./QA-CHECKLIST.md) 的手测项。

## 真值表

下表与 fixture 内容一致，由 `ios/SYCompressPlan.m` 原生编译执行产出。

| 输入 (w×h) | 采样倍率 | 输出 (w×h) | 说明 |
|---|---|---|---|
| 4032×3024 | 2 | 2016×1512 | 典型手机横拍原图 |
| 3024×4032 | 2 | 1512×2016 | 竖拍 |
| 1920×1080 | 1 | 1920×1080 | 比例恰为 0.5625，**不满足** `> 0.5625`，落入第二分支 `1920/1280 = 1` |
| 1280×720 | 1 | 1280×720 | 不压 |
| 1000×800 | 1 | 1000×800 | 不压 |
| 1665×1000 | 2 | 833×500 | |
| 4990×3000 | 4 | 1248×750 | |
| 10240×6000 | 8 | 1280×750 | |
| 1080×1920 | 1 | 1080×1920 | |
| 800×1600 | 1 | 800×1600 | |
| 640×1920 | 1 | 640×1920 | |
| 100×100 | 1 | 100×100 | |
| **1663×1663** | **2** | **832×832** | 见下方"已知怪癖" |
| **12000×1000** | **1** | **12000×1000** | 见下方"已知怪癖" |

## 已知怪癖（继承自 Luban，非本库引入）

两处都与 Android 现状一致，升级不会带来行为变化：

1. **1663×1663 的一像素悬崖**
   算法先把奇数边加一（1663 → 1664），而分档判断是 `< 1664`，于是 1662×1662
   不压缩、1663×1663 直接砍半。

2. **极宽图片反而不被压缩**
   比例 ≤ 0.5 时倍率为 `ceil(longSide / (1280 / ratio))`。以 12000×1000 为例：
   `ceil(12000 / 15366) = 1`，全景图会以原分辨率、质量 60 输出。

如果决定修掉第 2 点（例如给最终长边加一个 4096 的上限），那属于**对 Android
现状的行为变更**，需要写进迁移指南。

## 如何复跑真值表

```sh
cd ios
cat > /tmp/plan_main.m <<'EOF'
#import <Foundation/Foundation.h>
#import "SYCompressPlan.h"
int main(void){@autoreleasepool{
  NSArray *c=@[@[@4032,@3024],@[@1663,@1663],@[@12000,@1000]];
  for(NSArray *x in c){NSInteger w=[x[0] integerValue],h=[x[1] integerValue];
    NSInteger s=[SYCompressPlan autoSampleSizeForWidth:w height:h];
    NSLog(@"%ldx%ld sample=%ld -> %.0fx%.0f",(long)w,(long)h,(long)s,ceil((double)w/s),ceil((double)h/s));}
}return 0;}
EOF
clang -fobjc-arc -framework Foundation -I . /tmp/plan_main.m SYCompressPlan.m -o /tmp/plan && /tmp/plan
```
