//
//  DTXServerModel.h
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTXServerModel : NSObject

@property (nonatomic, strong) NSString *server;

@property (nonatomic, strong) NSString *selector;

@property (nonatomic, assign) uint32_t channel;

@property (nonatomic, assign) uint32_t identifier;

@end

NS_ASSUME_NONNULL_END
