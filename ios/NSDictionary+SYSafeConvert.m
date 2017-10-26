//
//  NSMutableDictionary+SYSafeConvert.m
//  RNSyanImagePicker
//
//  Created by CookieJ on 2017/10/18.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import "NSDictionary+SYSafeConvert.h"

@implementation NSMutableDictionary (SYSafeConvert)

- (void)sy_setObject:(id)value forKey:(NSString *)key {
    if (![self isKindOfClass:[NSMutableDictionary class]]) {
        NSLog(@"类型有误，非字典无法设置值！");
        return;
    }
    
    if (value && value != [NSNull null] && key) {
        [self setObject:value forKey:key];
    }
}

- (void)sy_setBool:(BOOL)value forKey:(NSString *)key {
    if (![self isKindOfClass:[NSMutableDictionary class]]) {
        NSLog(@"类型有误，非字典无法设置值！");
        return;
    }
    
    if (key) {
        [self setObject:@(value) forKey:key];
    }
}

- (void)sy_setInteger:(NSInteger)value forKey:(NSString *)key {
    if (![self isKindOfClass:[NSMutableDictionary class]]) {
        NSLog(@"类型有误，非字典无法设置值！");
        return;
    }
    
    if (key) {
        [self setObject:@(value) forKey:key];
    }
}

@end

@implementation NSDictionary (SYSafeConvert)

- (BOOL)sy_boolForKey:(NSString *)key {
    if (![self isKindOfClass:[NSDictionary class]]) {
        NSLog(@"类型有误，无法从非字典取值！");
        return nil;
    }
    
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
        return [value boolValue];
    }
    return NO;
}

- (NSInteger)sy_integerForKey:(NSString *)key {
    if (![self isKindOfClass:[NSDictionary class]]) {
        NSLog(@"类型有误，无法从非字典取值！");
        return nil;
    }
    
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
        return [value integerValue];
    }
    return 0;
}

- (NSString *)sy_stringForKey:(NSString *)key {
    if (![self isKindOfClass:[NSDictionary class]]) {
        NSLog(@"类型有误，无法从非字典取值！");
        return nil;
    }
    
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return nil;
}

@end
