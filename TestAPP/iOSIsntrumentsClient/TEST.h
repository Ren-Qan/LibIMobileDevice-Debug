//
//  TEST.h
//  cccc
//
//  Created by 任玉乾 on 2022/11/16.
//

#import <Foundation/Foundation.h>




NS_ASSUME_NONNULL_BEGIN

@interface TEST : NSObject
//(int argc, const char **argv)

+ (void)testWithC:(NSInteger)c andArgv:(NSArray<NSString *> *)argv;

@end

NS_ASSUME_NONNULL_END