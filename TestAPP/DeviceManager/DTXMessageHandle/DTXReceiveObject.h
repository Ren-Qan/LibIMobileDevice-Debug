//
//  DTXReceiveObject.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTXReceiveObject : NSObject

- (BOOL)exist;

- (NSArray *)arrayResult;

- (id)objectResult;

- (uint32_t)channel;

- (uint32_t)identifier;

- (uint32_t)flag;

- (void)setIdentifier:(uint32_t)identifier;

- (void)setChannel:(uint32_t)channel;

- (void)setFlag:(uint32_t)flag;

- (void)deserializeWithData:(NSData *)data;

- (void)unarchiverWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
