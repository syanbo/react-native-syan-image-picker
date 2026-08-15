#import <Foundation/Foundation.h>

#import "SYRequestGate.h"

static void expect(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        SYRequestGate *gate = [SYRequestGate new];

        NSObject *first = [gate begin];
        expect(first != nil, @"第一次请求应取得令牌");
        expect(gate.isActive, @"取得令牌后应处于占用状态");
        expect([gate begin] == nil, @"占用期间的第二次请求应被拒绝");

        NSObject *foreign = [NSObject new];
        expect(![gate finish:foreign], @"非当前令牌不能释放闸门");
        expect(gate.isActive, @"无效释放后仍应保持占用");

        expect([gate finish:first], @"当前令牌应能释放闸门");
        expect(!gate.isActive, @"释放后应恢复空闲");
        expect(![gate finish:first], @"同一令牌不能重复结算");

        NSObject *second = [gate begin];
        expect(second != nil, @"前一请求结束后应允许新请求");
        expect(![gate finish:first], @"旧请求迟到的回调不能释放新请求");
        expect(gate.isActive, @"旧令牌结算后新请求仍应保持占用");
        expect([gate finish:second], @"新请求应由自己的令牌释放");

        // 模拟多个原生入口在不同队列同时抢占，最终只能有一个赢家。
        SYRequestGate *concurrentGate = [SYRequestGate new];
        NSObject *resultLock = [NSObject new];
        __block NSInteger winnerCount = 0;
        __block NSObject *winningToken = nil;
        dispatch_apply(32, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                       ^(size_t index) {
                           NSObject *candidate = [concurrentGate begin];
                           if (candidate) {
                               @synchronized(resultLock) {
                                   winnerCount += 1;
                                   winningToken = candidate;
                               }
                           }
                       });
        expect(winnerCount == 1, @"并发 begin 只能有一个请求取得令牌");
        expect([concurrentGate finish:winningToken], @"并发赢家应能正常释放闸门");

        NSLog(@"SYRequestGate tests passed");
    }
    return 0;
}
