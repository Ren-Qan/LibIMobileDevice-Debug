//
//  DeviceInfoModel.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

#import <Foundation/Foundation.h>

#import "DeviceCommonConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeviceInfoModel : NSObject

@property (copy) NSString * udid;

@property (assign) DeviceConnectType connectType;

@end

NS_ASSUME_NONNULL_END
