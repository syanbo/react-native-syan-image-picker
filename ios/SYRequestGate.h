#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 同一时刻只允许一个会展示原生界面的请求。
 *
 * begin 返回请求专属令牌；finish 只有在令牌仍是当前请求时才会释放闸门。
 * 因此旧请求迟到的回调不能误清掉新请求。
 */
@interface SYRequestGate : NSObject

@property (nonatomic, readonly, getter=isActive) BOOL active;

- (nullable NSObject *)begin;
- (BOOL)finish:(NSObject *)token;

@end

NS_ASSUME_NONNULL_END
