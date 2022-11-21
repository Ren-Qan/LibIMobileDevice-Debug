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

- (void)addData:(NSData *)data {
    if (data == NULL) {
        return;
    }
    [self.bytevec_t appendData:data];
}

- (void)appendData:(NSData *)data {
    [self append_d:10];
    [self append_d:2];
    
    [self append_d:(uint32_t)data.length];
    [self append_b:data];
}

- (void)appendInt:(int32_t)num {
    [self append_d:10];
    [self append_d:3];
    [self append_d:num];
}

- (void)appendLong:(int64_t)num {
    [self append_d:10];
    [self append_d:4];
    [self append_q:num];
}

//MARK: - Common -

- (void)append_d:(uint32_t)num {
    [self append_v:&num len:sizeof(num)];
}

- (void)append_q:(uint64_t)num {
    [self append_v:&num len:sizeof(num)];
}

- (void)append_b:(NSData *)data {
    [self append_v:data.bytes len:data.length];
}

- (void)append_v:(const void *)v len:(NSUInteger)len {
    [self.bytevec_t appendBytes:v length:len];
}

@end
