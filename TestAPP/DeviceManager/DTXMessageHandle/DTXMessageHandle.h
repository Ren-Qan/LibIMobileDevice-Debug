//
//  DTXMessageHandle.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/21.
//

#import <Foundation/Foundation.h>
#import "DTXArguments.h"
#import "DTXReceiveObject.h"

#include <libimobiledevice/libimobiledevice.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DTXMessageHandleDelegate <NSObject>

- (void)receiveWithServer:(NSString *)server andObject:(DTXReceiveObject *)object;

@optional

- (void)shakeHandFinishWithState:(BOOL)state;

@end

@interface DTXMessageHandle : NSObject

@property (nonatomic, weak) id<DTXMessageHandleDelegate> delegate;

- (instancetype)initWithDevice:(idevice_t)device;

- (void)responseForServer:(NSString *)server
                 selector:(NSString *)selector
                     args:(nullable DTXArguments *)args;

- (void)requestForReceive;

- (void)removeServer:(NSString *)server;

@end

NS_ASSUME_NONNULL_END
