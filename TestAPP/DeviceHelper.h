//
//  DeviceHelper.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeviceHelper : NSObject

+ (instancetype)shared;

- (NSArray<NSString *> *)getDeviceList;

@end

NS_ASSUME_NONNULL_END
