#!/usr/bin/env bash
#
# iOS 侧单元测试。
#
# 不需要模拟器、不需要 Xcode test target、不改 podspec —— 被测的三个类
# （SYCompressPlan / SYImageCodec / SYRequestGate）只依赖系统框架，
# 这些框架在 macOS 上同样存在，直接编成命令行程序跑即可，耗时秒级。
#
# 用法：./ios/tests/run.sh   （从仓库根目录执行）

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

CFLAGS=(-fobjc-arc -Wall -Wextra -Wno-unused-parameter -I "$ROOT/ios")
FRAMEWORKS=(-framework Foundation -framework CoreGraphics -framework ImageIO)

echo "== 编译 =="
clang "${CFLAGS[@]}" "${FRAMEWORKS[@]}" \
  "$ROOT/ios/tests/plan_test.m" "$ROOT/ios/SYCompressPlan.m" \
  -o "$BUILD/plan_test"

clang "${CFLAGS[@]}" "${FRAMEWORKS[@]}" \
  "$ROOT/ios/tests/codec_test.m" "$ROOT/ios/SYImageCodec.m" \
  -o "$BUILD/codec_test"

clang "${CFLAGS[@]}" "${FRAMEWORKS[@]}" \
  "$ROOT/ios/tests/request_gate_test.m" "$ROOT/ios/SYRequestGate.m" \
  -o "$BUILD/request_gate_test"

echo
"$BUILD/plan_test" "$ROOT/__fixtures__/compress-plan.json"
echo
"$BUILD/codec_test"
echo
"$BUILD/request_gate_test"
