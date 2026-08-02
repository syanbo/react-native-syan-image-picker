/*
 * 压缩算法一致性测试。
 *
 * 读取 __fixtures__/compress-plan.json —— **与 Android 的 CompressPlanTest 是同一份
 * 文件**。这一点很关键：两端各自维护期望值的话，测试只会各自变绿，漂移照样发生。
 *
 * 不需要模拟器，也不需要 Xcode test target：SYCompressPlan 只依赖 Foundation，
 * 用 clang 直接编成命令行程序即可。见 ios/tests/run.sh。
 */

#import <Foundation/Foundation.h>

#import "SYCompressPlan.h"

static int gFailures = 0;

static void expectEqual(NSInteger actual, NSInteger expected, NSString *what) {
    if (actual != expected) {
        fprintf(stderr, "  ✗ %s: 期望 %ld，实际 %ld\n",
                what.UTF8String, (long)expected, (long)actual);
        gFailures++;
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *fixturePath = argc > 1
            ? [NSString stringWithUTF8String:argv[1]]
            : @"__fixtures__/compress-plan.json";

        NSData *data = [NSData dataWithContentsOfFile:fixturePath];
        if (!data) {
            fprintf(stderr, "找不到 fixture: %s\n", fixturePath.UTF8String);
            return 2;
        }

        NSError *error = nil;
        NSArray *cases = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (![cases isKindOfClass:[NSArray class]]) {
            fprintf(stderr, "fixture 解析失败: %s\n", error.localizedDescription.UTF8String);
            return 2;
        }

        printf("压缩算法一致性（%lu 个用例）\n", (unsigned long)cases.count);

        for (NSDictionary *c in cases) {
            NSInteger width = [c[@"width"] integerValue];
            NSInteger height = [c[@"height"] integerValue];
            NSString *name = c[@"name"] ?: @"?";

            NSInteger sample = [SYCompressPlan autoSampleSizeForWidth:width height:height];
            expectEqual(sample, [c[@"sampleSize"] integerValue],
                        [NSString stringWithFormat:@"%@ sampleSize", name]);

            // 输出尺寸按与 Android 相同的方式推导：ceil(边长 / 倍率)
            NSInteger outW = width == 0 ? 0 : (NSInteger)ceil((double)width / sample);
            NSInteger outH = height == 0 ? 0 : (NSInteger)ceil((double)height / sample);
            expectEqual(outW, [c[@"outWidth"] integerValue],
                        [NSString stringWithFormat:@"%@ outWidth", name]);
            expectEqual(outH, [c[@"outHeight"] integerValue],
                        [NSString stringWithFormat:@"%@ outHeight", name]);
        }

        // normalizeSampleSize 必须永远吐出 2 的幂 —— 这是两端尺寸一致的前提。
        expectEqual([SYCompressPlan normalizeSampleSize:0], 1, @"normalize(0)");
        expectEqual([SYCompressPlan normalizeSampleSize:1], 1, @"normalize(1)");
        expectEqual([SYCompressPlan normalizeSampleSize:3], 2, @"normalize(3)");
        expectEqual([SYCompressPlan normalizeSampleSize:7], 4, @"normalize(7)");
        expectEqual([SYCompressPlan normalizeSampleSize:8], 8, @"normalize(8)");
        expectEqual([SYCompressPlan normalizeSampleSize:100], 64, @"normalize(100)");

        // fitSize：边界框，等比，永不放大
        CGSize fit = [SYCompressPlan fitSize:CGSizeMake(4000, 3000) maxWidth:1000 maxHeight:0];
        expectEqual((NSInteger)fit.width, 1000, @"fit 宽度上限");
        expectEqual((NSInteger)fit.height, 750, @"fit 等比高度");

        fit = [SYCompressPlan fitSize:CGSizeMake(800, 600) maxWidth:2000 maxHeight:2000];
        expectEqual((NSInteger)fit.width, 800, @"fit 不放大");

        fit = [SYCompressPlan fitSize:CGSizeMake(4000, 3000) maxWidth:1000 maxHeight:500];
        expectEqual((NSInteger)fit.height, 500, @"fit 取更紧的一边");

        if (gFailures == 0) {
            printf("✓ 全部通过\n");
            return 0;
        }
        fprintf(stderr, "✗ %d 处失败\n", gFailures);
        return 1;
    }
}
