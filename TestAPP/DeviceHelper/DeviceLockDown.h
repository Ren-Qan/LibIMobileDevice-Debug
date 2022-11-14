//
//  DeviceLockDown.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeviceLockDown : NSObject

- (instancetype)initWithUDID:(NSString *)UDID;

- (void)testAPI;

@end

NS_ASSUME_NONNULL_END
