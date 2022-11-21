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

#include "libimobiledevice.h"
#include "DTXMessageService.hh"

static void instruments_call_back(uint32_t channel, void * object) {
    printf("=======%d\n", channel);
}

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
    idevice_new_with_options(&device, list[0], IDEVICE_LOOKUP_NETWORK);

    idevice_connection_t conn;
    instruments_start_connection(device, &conn, instruments_call_back);
    
    const void *procAttrs_values[] = {CFSTR("memVirtualSize"), CFSTR("cpuUsage"), CFSTR("ctxSwitch"), CFSTR("intWakeups"),CFSTR("physFootprint"), CFSTR("memResidentSize"), CFSTR("memAnon"), CFSTR("pid")};
    int _bm = 0; // don't suspend the process after starting it
    int _ur = 1000; // kill the application if it is already running
    int _cpuUsage = 1; // kill the application if it is already running
    int _sampleInterval = 1000000000; // kill the application if it is already running
    
    CFNumberRef bm = CFNumberCreate(NULL, kCFNumberSInt32Type, &_bm);
    CFNumberRef ur = CFNumberCreate(NULL, kCFNumberSInt32Type, &_ur);
    CFNumberRef cpuUsage = CFNumberCreate(NULL, kCFNumberSInt32Type, &_cpuUsage);
    CFNumberRef sampleInterval = CFNumberCreate(NULL, kCFNumberSInt32Type, &_sampleInterval);
    CFArrayRef procAttrs = CFArrayCreate(NULL, procAttrs_values, 8, NULL);
    
    const void *keys[] =
    {
        CFSTR("bm"),
        CFSTR("cpuUsage"),
        CFSTR("procAttrs"),
        CFSTR("sampleInterval"),
        CFSTR("ur")
    };
    
    const void *values[] = { bm, cpuUsage, procAttrs, sampleInterval, ur};
    
    CFDictionaryRef dic = CFDictionaryCreate(NULL, keys, values, 5, NULL, NULL);
    
    message_aux_t args;
    args.append_obj(dic);
    
    int cpu_channel_code = instrument_make_channel(conn, CFSTR("com.apple.instruments.server.services.sysmontap"));
    instruments_response(conn, cpu_channel_code, (char *)CFSTR("setConfig:"), &args);
    instruments_response(conn, cpu_channel_code, (char *)CFSTR("start"), NULL);
    
    int i = 0;
    while (i < 10000) {
        instrument_receive(conn);
        i++;
    }

    instrument_connection_free(conn);
    idevice_free(device);
    
    return 0;
}


