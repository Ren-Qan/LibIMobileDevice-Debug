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

bool hand_shake(idevice_connection_t conn);

bool send_message(idevice_connection_t conn,
                         int channel,
                         char * selector,
                         const message_aux_t *args,
                         bool expects_reply);

bool recv_message(idevice_connection_t conn,
                         CFTypeRef * retobj,
                         CFArrayRef * aux);

int make_channel(idevice_connection_t conn,
                        CFStringRef identifier);

#endif /* DTXMessageService */
