//
//  DeviceHelper.m
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

#import "DeviceHelper.h"
#import <libimobiledevice/libimobiledevice.h>

static void subscribe_event_cb(const idevice_event_t *event, void *user_data) {
    if (event -> event == IDEVICE_DEVICE_ADD) {
        NSLog(@"\n*********[CONNECT]************\n[UDID] : [%s]\n[TYPE] : [%@]\n*********************", event -> udid, event -> conn_type == CONNECTION_USBMUXD ? @"USB" : @"NET");
    } else if (event -> event == IDEVICE_DEVICE_REMOVE) {
        NSLog(@"[NOT FIND]");
    }
}

@implementation DeviceHelper

+ (instancetype)shared {
    static DeviceHelper *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DeviceHelper alloc] init];
        [sharedInstance subscribeDevice];
    });
    return sharedInstance;
}

- (void)subscribeDevice {
    idevice_event_subscribe(subscribe_event_cb, NULL);
}


- (NSArray<DeviceInfoModel *> *)getDeviceList {
    NSMutableArray<DeviceInfoModel *> *arr = [NSMutableArray array];

    int count = 0;
    idevice_info_t *list = NULL;

    idevice_get_device_list_extended(&list, &count);
    
    for (int i = 0; i < count; i++) {
        idevice_info_t current = list[i];
        
        DeviceInfoModel *model = [[DeviceInfoModel alloc] init];
        model.udid = [[NSString alloc] initWithUTF8String:current -> udid];
        model.connectType = current -> conn_type == CONNECTION_USBMUXD ? DeviceConnectTypeUSB : DeviceConnectTypeNet;
        [arr addObject:model];
    }

    idevice_device_list_extended_free(list);
    
    return  arr;
}


- (void)testAPI {
    
}

@end
