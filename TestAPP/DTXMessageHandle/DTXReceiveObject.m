//
//  DTXReceiveObject.m
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/22.
//

#import "DTXReceiveObject.h"

@interface DTSysmonTapMessage : NSObject<NSSecureCoding>

@property (nonatomic, strong) NSObject * dic;

@end

@implementation DTSysmonTapMessage

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeObject:self.dic forKey:@"DTTapMessagePlist"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    if (self = [super init]) {
        self.dic = [coder decodeObjectForKey:@"DTTapMessagePlist"];
    }
    return self;
}

@end

// MARK: --------------------------------------------------------------------------------

@implementation DTXReceiveObject {
    NSArray *_array;
    NSObject *_object;
    uint32_t _channelCode;
    uint32_t _identifier;
    uint32_t _flag;
}

- (NSArray *)array {
    return _array;
}

- (id)object {
    return _object;
}

- (uint32_t)channel {
    return _channelCode;
}

- (uint32_t)identifier {
    return _identifier;
}

- (uint32_t)flag {
    return _flag;
}

- (void)setIdentifier:(uint32_t)identifier {
    _identifier = identifier;
}

- (void)setChannel:(uint32_t)channel {
    _channelCode = channel;
}

- (void)setFlag:(uint32_t)flag {
    _flag = flag;
}

- (void)deserializeWithData:(NSData *)data {
    if (data == NULL) {
        return;
    }
    
    if (data.length < 16) {
        return;
    }
    
    uint64_t size = *((uint64_t *)data.bytes + 1);
    if (size > data.length) {
        return;
    }
    
    NSMutableArray *array = [NSMutableArray array];
    
    uint64_t off = sizeof(uint64_t) * 2;
    uint64_t end = off + size;
    
    while (off < end) {
        int length = 0;
        int type = *((int *)(data.bytes + off));
        off += sizeof(int);
        
        NSObject *item = NULL;
        
        switch (type) {
            case 2:
                length = *((int *)(data.bytes + off));
                off += sizeof(int);
                break;
                
            case 3:
            case 5:
                length = 4;
                break;
                
            case 4:
            case 6:
                length = 8;
                break;
                
            case 10:
                continue;
                
            default:
                break;
        }
        
        item = [self unarchiveWithBytes:data.bytes + off len:length];
        
        if ( item == NULL ) {
            return;
        }
        [array addObject:item];
        off += length;
    }
    
    if (array.count > 0) {
        _array = array;
    }
}

- (void)unarchiverWithData:(NSData *)data {
    if (data == NULL) {
        return;
    }
    _object = [self unarchiverData:data];
}

- (id)unarchiveWithBytes:(const void *)bytes len:(int)len {
    if (len == 0) {
        return NULL;
    }
    NSData *data = [NSData dataWithBytesNoCopy:(void *)bytes length:len freeWhenDone:false];
    return [self unarchiverData:data];
}

- (NSObject *)unarchiverData:(NSData *)data {
    if (!data) {
        return NULL;
    }
    NSError *error;
    NSObject *object = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error];
    
    if ([object isKindOfClass:[DTSysmonTapMessage class]]) {
        return [(DTSysmonTapMessage *)object dic];
    }
    
    return object;
}

@end
