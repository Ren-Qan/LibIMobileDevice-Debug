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
    usbmuxd_device_info_t * list = NULL;
    int count = usbmuxd_get_device_list(&list);

    char net[4] = "NET";
    char usb[4] = "USB";
    
    for (int i = 0; i < count; i++) {
        printf("[CONNECT] - [%s] - [UUID] - [%s]\n", list[i].conn_type == CONNECTION_TYPE_NETWORK ? net : usb, list[i].udid);
    }
    
    if (count == 0) {
        printf("NONE\n");
    }
    
    return 0;
}
