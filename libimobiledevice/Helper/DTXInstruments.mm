//
//  Instruments.cpp
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/19.
//

#include "DTXInstruments.hh"

bool print_proclist(idevice_connection_t conn) {
    int channel = make_channel(conn, CFSTR("com.apple.instruments.server.services.deviceinfo"));
    if ( channel < 0 )
        return false;
    
    CFTypeRef retobj = NULL;
    
    if (!send_message(conn, channel, (char *)CFSTR("runningProcesses"), NULL, true)
        || !recv_message(conn, &retobj, NULL)
        || retobj == NULL )
    {
        fprintf(stderr, "Error: failed to retrieve return value for runningProcesses\n");
        return false;
    }
    
    bool ok = true;
    if ( CFGetTypeID(retobj) == CFArrayGetTypeID() )
    {
        CFArrayRef array = (CFArrayRef)retobj;
        
        printf("proclist:\n");
        for ( size_t i = 0, size = CFArrayGetCount(array); i < size; i++ )
        {
            CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(array, i);
            
            CFStringRef _name = (CFStringRef)CFDictionaryGetValue(dict, CFSTR("name"));
            string_t name = to_stlstr(_name);
            
            CFNumberRef _pid = (CFNumberRef)CFDictionaryGetValue(dict, CFSTR("pid"));
            int pid = 0;
            CFNumberGetValue(_pid, kCFNumberSInt32Type, &pid);
            
            printf("%6d %s\n", pid, name.c_str());
        }
    } else {
        fprintf(stderr, "Error: process list is not in the expected format: %s\n", get_description(retobj).c_str());
        ok = false;
    }
    
    CFRelease(retobj);
    return ok;
}
