//
//  DTXReceiveObject.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTXReceiveObject : NSObject

@property (nonatomic, strong, nullable, readonly) NSArray *array;

@property (nonatomic, strong, nullable, readonly) id object;

@property (nonatomic, assign) uint32_t channel;

@property (nonatomic, assign) uint32_t identifier;

@property (nonatomic, assign) uint32_t flag;

- (void)deserializeWithData:(NSData *)data;

- (void)unarchiverWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
