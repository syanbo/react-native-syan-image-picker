//
//  NSMutableDictionary+SYSafeConvert.h
//  RNSyanImagePicker
//
//  Created by CookieJ on 2017/10/18.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (SYSafeConvert)

- (void)sy_setObject:(id)value forKey:(NSString *)key;

- (void)sy_setInteger:(NSInteger)value forKey:(NSString *)key;

- (void)sy_setBool:(BOOL)value forKey:(NSString *)key;

@end

@interface NSDictionary (SYSafeConvert)

- (NSString *)sy_stringForKey:(NSString *)key;

- (BOOL)sy_boolForKey:(NSString *)key;

- (NSInteger)sy_integerForKey:(NSString *)key;

@end
