//
//  main.c
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/11.
//

#include <stdio.h>
#include <stdlib.h>

#include "libimobiledevice.h"

int main(int argc, const char * argv[]) {
    // insert code here...
    
    idevice_info_t ** devices = (idevice_info_t **)malloc(sizeof(idevice_info_t *));
    int count = 0;
    
    idevice_error_t state = idevice_get_device_list_extended(devices, &count);
    
    if (state == IDEVICE_E_SUCCESS && count > 0) {
        idevice_info_t device = NULL;
        for (int i = 0; i < count; i++) {
            device = *(devices[i]);
            if (device != NULL) {
                printf("[UUID] - [%s]\n", device -> udid);
            }
        }
    } else {
        printf("\n[ERROR] - [%d]\n", state);
    }
    
    return 0;
}
