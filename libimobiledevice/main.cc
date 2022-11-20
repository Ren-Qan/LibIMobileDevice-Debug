//
//  main.c
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/11.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libimobiledevice.h"
#import "DTXInstruments.hh"

int main(int argc, const char * argv[]) {
    // insert code here...
//    idevice_set_debug_level(1);
    char ** list = NULL;
    int count = 0;
    
    idevice_error_t state = idevice_get_device_list(&list, &count);
    
    if (state == IDEVICE_E_SUCCESS && count > 0) {
        for (int i = 0; i < count; i++) {
            printf("[UUID] - [%s]\n", list[i]);
        }
    } else {
        printf("\n[ERROR] - [%d]\n", state);
    }
    
    // creat Device
    idevice_t device = NULL;
    idevice_new_with_options(&device, list[0], IDEVICE_LOOKUP_USBMUX);

    idevice_connection_t conn;
    instruments_start_connection(device, &conn);
    print_proclist(conn);
    print_cpu(conn);

    instrument_connection_free(conn);
    
    
    idevice_free(device);
    return 0;
}


