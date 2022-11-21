//
//  DTXMessageManager.hh
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/19.
//

#ifndef DTXMessageService_hh
#define DTXMessageService_hh

#include <stdio.h>

#import "DTXMessage.hh"

typedef void (*instruments_cb_t)(int channel, void * object);

typedef uint32_t instruments_error;

instruments_error instruments_start_connection(idevice_t device,
                                               idevice_connection_t * conn,
                                               instruments_cb_t call_back);

void instrument_connection_free(idevice_connection_t conn);

int instrument_make_channel(idevice_connection_t conn,
                            CFStringRef identifier);

bool instruments_response(idevice_connection_t conn,
                          int channel_code,
                          char *selector,
                          const message_aux_t * aux);

void instrument_receive(idevice_connection_t conn,
                        int channel_code);

#endif /* DTXMessageService */
