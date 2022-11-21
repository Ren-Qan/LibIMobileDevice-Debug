//
//  DTXArguments.m
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/21.
//

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#import "DTXArguments.h"
@interface DTXArguments()

@property (nonatomic, strong) NSMutableData *bytevec_t;

@end

@implementation DTXArguments

- (NSMutableData *)bytevec_t {
    if (!_bytevec_t) {
        _bytevec_t = [[NSMutableData alloc] init];
    }
    return _bytevec_t;
}

- (NSData *)bytes {
    return [self bytevec_t];
}

- (void)appendData:(NSData *)data {
    [self addpend_d:10];
    [self addpend_d:2];
    
    [self addpend_d:(uint32_t)data.length];
    [self addpend_b:data];
}

- (void)appendInt:(int32_t)num {
    [self addpend_d:10];
    [self addpend_d:3];
    [self addpend_d:num];
}

- (void)appendLong:(int64_t)num {
    [self addpend_d:10];
    [self addpend_d:4];
    [self addpend_q:num];
}

//MARK: - Private Common -

- (void)addpend_d:(uint32_t)num {
    [self addpend_v:&num len:sizeof(num)];
}

- (void)addpend_q:(uint64_t)num {
    [self addpend_v:&num len:sizeof(num)];
}

- (void)addpend_b:(NSData *)data {
    [self addpend_v:data.bytes len:data.length];
}

- (void)addpend_v:(const void *)v len:(NSUInteger)len {
    [self.bytevec_t appendBytes:v length:len];
}

@end
