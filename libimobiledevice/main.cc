//
//  main.c
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/11.
//

//#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mobilebackup2.h"
#include "libimobiledevice.h"

int main(int argc, const char * argv[]) {
    char ** list = NULL;
    int count = 0;
    
    idevice_error_t state = idevice_get_device_list(&list, &count);
    
    if (state == IDEVICE_E_SUCCESS && count > 0) {
        for (int i = 0; i < count; i++) {
            printf("[ID] - [%s]\n", list[i]);
        }
    } else {
        printf("\n[ERROR] - [%d]\n", state);
    }
    
    if (count < 1) {
        printf("\n device not found");
        return -1;
    }
    
    // creat Device
    idevice_t device = NULL;
    idevice_new_with_options(&device, list[0], IDEVICE_LOOKUP_NETWORK);
    
    idevice_connection_t _connection;
    if (device != NULL) {
        idevice_error_t error = idevice_connect(device, 58783, &_connection);
        printf("========\(%d)========\n", error);
    }
    
    if (_connection) {
        printf("========\(successs)========\n");
    }
    
    if (device) {
        idevice_free(device);
    }
    
    if (_connection) {
        idevice_disconnect(_connection);
    }
    
    printf("\n");
    return 0;
}


