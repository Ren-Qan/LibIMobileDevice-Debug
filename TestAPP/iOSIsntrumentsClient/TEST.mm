//
//  TEST.m
//  cccc
//
//  Created by 任玉乾 on 2022/11/16.
//

#import "TEST.h"

#include "ios_instruments_client.h"

@implementation TEST

+ (void)testWithArgv:(NSArray<NSString *> *)argv {
    load();
    am_device_service_connection *connect = getDeviceServiceConnection();
    printAppList();
    
    NSLog(@"");
}

@end
