//
//  DTXMessageHandle.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/21.
//

#import <Foundation/Foundation.h>
#import "DTXArguments.h"

#include <libimobiledevice/libimobiledevice.h>

NS_ASSUME_NONNULL_BEGIN

struct DTXMessageHeader
{
    uint32_t magic;
    uint32_t cb;
    uint16_t fragmentId;
    uint16_t fragmentCount;
    uint32_t length;
    uint32_t identifier;
    uint32_t conversationIndex;
    uint32_t channelCode;
    uint32_t expectsReply;
};

//-----------------------------------------------------------------------------
struct DTXMessagePayloadHeader
{
    uint32_t flags;
    uint32_t auxiliaryLength;
    uint64_t totalLength;
};

@protocol DTXMessageHandleDelegate <NSObject>

@optional

- (void)shakeHandFinishWithState:(BOOL)state;

@end

@interface DTXMessageHandle : NSObject

@property (nonatomic, weak) id<DTXMessageHandleDelegate> delegate;

- (instancetype)initWithDevice:(idevice_t)device;

@end

NS_ASSUME_NONNULL_END
