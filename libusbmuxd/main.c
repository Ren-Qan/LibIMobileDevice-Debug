//
//  main.c
//  libusbmuxd
//
//  Created by 任玉乾 on 2022/11/10.
//

#include <stdio.h>
#include <stdlib.h>

#include "usbmuxd.h"

int main(int argc, const char * argv[]) {
    int count = 0;
    usbmuxd_device_info_t ** list = (usbmuxd_device_info_t **)malloc(sizeof(usbmuxd_device_info_t *));
    
    count = usbmuxd_get_device_list(list);

    usbmuxd_device_info_t * device = NULL;
    for (int i = 0; i < count; i++) {
        device = list[i];
        if (device != NULL) {
            printf("[CONNECTT] - [%d] - [UUID] - [%s]\n", device -> conn_type, device -> udid);
        }
    }
    
    return 0;
}
