#import "SYRequestGate.h"

@interface SYRequestGate ()
@property (nonatomic, strong, nullable) NSObject *activeToken;
@end

@implementation SYRequestGate

- (nullable NSObject *)begin {
    @synchronized(self) {
        if (self.activeToken) {
            return nil;
        }
        NSObject *token = [NSObject new];
        self.activeToken = token;
        return token;
    }
}

- (BOOL)finish:(NSObject *)token {
    @synchronized(self) {
        if (!token || self.activeToken != token) {
            return NO;
        }
        self.activeToken = nil;
        return YES;
    }
}

- (BOOL)isActive {
    @synchronized(self) {
        return self.activeToken != nil;
    }
}

@end
