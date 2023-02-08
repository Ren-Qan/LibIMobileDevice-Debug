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
    idevice_new(&device, list[0]);

    mobilebackup2_client_t client = NULL;
    mobilebackup2_error_t error = mobilebackup2_client_start_service(device, &client, "asd");
    
    if (error == MOBILEBACKUP2_E_SUCCESS) {
        printf("\n mobilebackup2 success\n");
    } else {
        printf("\n mobilebackup2 error %d\n", error);
    }
    
    if (client) {
        mobilebackup2_client_free(client);
    }
    
    if (device) {
        idevice_free(device);
    }

    printf("\n");
    return 0;
}


