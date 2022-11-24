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

- (void)receiveWithServer:(NSString *)server object:(DTXReceiveObject *)object handle:(DTXMessageHandle *)handle ;

@optional

- (void)error:(NSString *)error handle:(DTXMessageHandle *)handle;

@end

@interface DTXMessageHandle : NSObject

@property (nonatomic, weak) id<DTXMessageHandleDelegate> delegate;

/// 断掉Instrument的socket
- (void)stopService;

- (BOOL)connectInstrumentsServiceWithDevice:(idevice_t)device;

/// 必须得 connectInstrumentsServiceWithDevice: 返回YES才可以执行
- (void)requestForServer:(NSString *)server
                 selector:(NSString *)selector
                     args:(nullable DTXArguments *)args;

/// 有些Service建立连接后直接读socket的缓存即可
- (void)responseForReceive;

- (BOOL)isServerBuildSuccessWithName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
