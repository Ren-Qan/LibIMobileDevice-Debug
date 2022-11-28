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

+ (instancetype)args {
    return [[DTXArguments alloc] init];
}

- (NSMutableData *)bytevec_t {
    if (!_bytevec_t) {
        _bytevec_t = [[NSMutableData alloc] init];
    }
    return _bytevec_t;
}

- (NSMutableData *)bytes {
    return [self bytevec_t];
}

- (NSData *)getArgBytes {
    if (_bytevec_t == NULL || _bytevec_t.length <= 0) {
        return NULL;
    }
    
    DTXArguments *result = [DTXArguments args];
    [result append_q:0x01F0];
    [result append_q:_bytevec_t.length];
    [result append_b:_bytevec_t];
    return result.bytes;
}

- (void)addObject:(id)object {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:NULL];
    if (data) {
        [self appendData:data];
    }
}

- (void)appendData:(NSData *)data {
    [self append_d:10];
    [self append_d:2];
    
    [self append_d:(uint32_t)data.length];
    [self append_b:data];
}

- (void)appendNum32:(int32_t)num {
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
    if (data == NULL) {
        return;
    }
    [self append_v:data.bytes len:data.length];
}

- (void)append_v:(const void *)v len:(NSUInteger)len {
    [self.bytevec_t appendBytes:v length:len];
}

@end
