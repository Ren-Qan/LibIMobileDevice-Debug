//
//  Instruments.hpp
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/19.
//

#ifndef Instruments_hh
#define Instruments_hh

#include <stdio.h>
#include <libimobiledevice/libimobiledevice.h>

#import "DTXMessageService.hh"

typedef uint32_t instruments_error;

char * _Nullable idevice_get_version(idevice_t _Nullable device);

instruments_error instruments_start_connection(idevice_t device, idevice_connection_t * conn);

void instrument_connection_free(idevice_connection_t conn);

bool print_proclist(idevice_connection_t _Nullable conn);

void print_cpu(idevice_connection_t conn);

#endif /* Instruments_hpp */
