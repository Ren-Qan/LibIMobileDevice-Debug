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
@class DTXMessageHandle;

@protocol DTXMessageHandleDelegate <NSObject>

@optional

- (void)error:(NSString *)error handle:(DTXMessageHandle *)handle;

@end

@interface DTXMessageHandle : NSObject

@property (nonatomic, weak) id<DTXMessageHandleDelegate> delegate;

- (void)stopService;

- (BOOL)connectInstrumentsServiceWithDevice:(idevice_t)device;

- (BOOL)isVaildServer:(NSString *)server;

- (BOOL)sendWithChannel:(uint32_t)channel
             identifier:(uint32_t)identifier
               selector:(NSString *)selector
                   args:(DTXArguments * _Nullable)args
           expectsReply:(BOOL)expectsReply;

- (DTXReceiveObject * _Nullable)receive;

@end

NS_ASSUME_NONNULL_END
