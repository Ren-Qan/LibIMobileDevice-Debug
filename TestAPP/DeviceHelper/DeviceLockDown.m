//
//  DeviceLockDown.m
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

#import <libimobiledevice/lockdown.h>

#import "DeviceLockDown.h"

@interface DeviceLockDown()

@property (nonatomic, copy) NSString * udid;

@end

@implementation DeviceLockDown {
    idevice_t _device;
    lockdownd_client_t _lockdownd_client;
}


- (instancetype)initWithUDID:(NSString *)UDID {
    if (self = [super init]) {
        self.udid = UDID;

        if (idevice_new(&_device, [UDID cStringUsingEncoding:NSUTF8StringEncoding]) == IDEVICE_E_SUCCESS) {
            if (lockdownd_client_new_with_handshake(_device, &_lockdownd_client, "RYQ") == LOCKDOWN_E_SUCCESS) {
                
            }
        }
    }
    return self;
}

- (void)dealloc {
    if (_lockdownd_client) {
        lockdownd_client_free(_lockdownd_client);
    }
    
    if (_device) {
        idevice_free(_device);
    }
}

- (void)testAPI {
    
}


@end
