//
//  DTXArguments.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTXArguments : NSObject

- (NSData *)bytes;

- (void)appendData:(NSData *)data;

- (void)appendInt:(int32_t)num;

- (void)appendLong:(int64_t)num;

@end

NS_ASSUME_NONNULL_END
