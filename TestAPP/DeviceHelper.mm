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


- (NSArray *)getDeviceList {
    int num = 0;
    char **devices = NULL;
    idevice_get_device_list(&devices, &num);
    NSMutableArray *deviceList = [NSMutableArray array];
    for (int i = 0; i < num; i++) {
        NSString *udid = [NSString stringWithFormat:@"%s", devices[i]];
        [deviceList addObject:udid];
    }
    idevice_device_list_free(devices);
    return deviceList;
}

@end
