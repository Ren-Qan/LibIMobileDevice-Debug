#include <unistd.h>

#include "ios_instruments_client.h"

static int cur_channel = 0;             // current channel id
static bool verbose = true;            // verbose mode (-v option)

static int cur_message = 0;
static CFDictionaryRef channels = NULL; // list of available channels published by the instruments server

//-----------------------------------------------------------------------------
void message_aux_t::append_int(int32_t val) {
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 3);   // 32-bit int
    append_d(buf, val);
}

//-----------------------------------------------------------------------------
void message_aux_t::append_long(int64_t val) {
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 4);   // 64-bit int
    append_q(buf, val);
}

//-----------------------------------------------------------------------------
void message_aux_t::append_obj(CFTypeRef obj) {
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 2);   // archived object
    
    bytevec_t tmp;
    archive(&tmp, obj);
    
    append_d(buf, uint32_t(tmp.size()));
    append_b(buf, tmp);
}

//-----------------------------------------------------------------------------
void message_aux_t::get_bytes(bytevec_t *out) const {
    if (!buf.empty()) {
        append_q(*out, 0x1F0);
        append_q(*out, buf.size());
        append_b(*out, buf);
    }
}

static bool send_message(idevice_connection_t conn,
                         int channel,
                         char * selector,
                         const message_aux_t *args,
                         bool expects_reply) {
    uint32_t id = ++cur_message;
    
    bytevec_t aux;
    if ( args != NULL )
        args->get_bytes(&aux);
    
    bytevec_t sel;
    if ( selector != NULL )
        archive(&sel, selector);
    
    DTXMessagePayloadHeader pheader;
    // the low byte of the payload flags represents the message type.
    // so far it seems that all requests to the instruments server have message type 2.
    pheader.flags = 0x2 | (expects_reply ? 0x1000 : 0);
    pheader.auxiliaryLength = uint32_t(aux.size());
    pheader.totalLength = aux.size() + sel.size();
    
    DTXMessageHeader mheader;
    mheader.magic = 0x1F3D5B79;
    mheader.cb = sizeof(DTXMessageHeader);
    mheader.fragmentId = 0;
    mheader.fragmentCount = 1;
    mheader.length = uint32_t(sizeof(pheader) + pheader.totalLength);
    mheader.identifier = id;
    mheader.conversationIndex = 0;
    mheader.channelCode = channel;
    mheader.expectsReply = (expects_reply ? 1 : 0);
    
    bytevec_t msg;
    append_v(msg, &mheader, sizeof(mheader));
    append_v(msg, &pheader, sizeof(pheader));
    append_b(msg, aux);
    append_b(msg, sel);
    
    uint32_t nsent;
    size_t msglen = msg.size();
    char *datas = (char *)msg.data();
    
    idevice_connection_send(conn, datas, (uint32_t)msglen, &nsent);
    
    if ( nsent != msglen ) {
        fprintf(stderr, "Failed to send 0x%lx bytes of message: %s\n", msglen, strerror(errno));
        return false;
    }
    
    return true;
}


static bool recv_message(idevice_connection_t conn,
                         CFTypeRef * retobj,
                         CFArrayRef * aux) {
    uint32_t id = 0;
    bytevec_t payload;
    
    while (true) {
        DTXMessageHeader mheader;
        uint32_t nrecv = 0;
        idevice_connection_receive(conn, (char *)(&mheader), sizeof(mheader), &nrecv);
        
        if (nrecv != sizeof(mheader)) {
            fprintf(stderr, "failed to read message header: %s, nrecv = %x\n", strerror(errno), nrecv);
            return false;
        }
        
        if ( mheader.magic != 0x1F3D5B79 ) {
            fprintf(stderr, "bad header magic: %x\n", mheader.magic);
            return false;
        }
        
        if ( mheader.conversationIndex == 1 ) {
            // the message is a response to a previous request, so it should have the same id as the request
            if ( mheader.identifier != cur_message )
            {
                fprintf(stderr, "expected response to message id=%d, got a new message with id=%d\n", cur_message, mheader.identifier);
                return false;
            }
        } else if ( mheader.conversationIndex == 0 ) {
            // the message is not a response to a previous request. in this case, different iOS versions produce different results.
            // on iOS 9, the incoming message can have the same message ID has the previous message we sent to the server.
            // on later versions, the incoming message will have a new message ID. we must be aware of both situations.
            if ( mheader.identifier > cur_message ) {
                // new message id, we must update the count on our side
                cur_message = mheader.identifier;
            }
            else if ( mheader.identifier < cur_message ) {
                // the id must match the previous request, anything else doesn't really make sense
                fprintf(stderr, "unexpected message ID: %d\n", mheader.identifier);
                return false;
            }
        } else {
            fprintf(stderr, "invalid conversation index: %d\n", mheader.conversationIndex);
            return false;
        }
        
        if ( mheader.fragmentId == 0 ) {
            id = mheader.identifier;
            // when reading multiple message fragments, the 0th fragment contains only a message header
            if ( mheader.fragmentCount > 1 )
                continue;
        }
        
        // read the entire payload in the current fragment
        bytevec_t frag;
        append_v(frag, &mheader, sizeof(mheader));
        frag.resize(frag.size() + mheader.length);
        
        uint8_t *data = frag.data() + sizeof(mheader);
        
        uint32_t nbytes = 0;
        while ( nbytes < mheader.length ) {
            uint8_t *curptr = data + nbytes;
            size_t curlen = mheader.length - nbytes;
            idevice_connection_receive(conn, (char *)curptr, (uint32_t)curlen, &nrecv);
            
            if ( nrecv <= 0 ) {
                fprintf(stderr, "failed reading from socket: %s\n", strerror(errno));
                return false;
            }
            nbytes += nrecv;
        }
        
        // append to the incremental payload
        append_v(payload, data, mheader.length);
        
        // done reading message fragments?
        if ( mheader.fragmentId == mheader.fragmentCount - 1 )
            break;
    }
    
    const DTXMessagePayloadHeader *pheader = (const DTXMessagePayloadHeader *)payload.data();
    
    // we don't know how to decompress messages yet
    uint8_t compression = (pheader->flags & 0xFF000) >> 12;
    if (compression != 0) {
        fprintf(stderr, "message is compressed (compression type %d)\n", compression);
        return false;
    }
    
    // serialized object array is located just after payload header
    const uint8_t *auxptr = payload.data() + sizeof(DTXMessagePayloadHeader);
    uint32_t auxlen = pheader->auxiliaryLength;
    
    // archived payload object appears after the auxiliary array
    const uint8_t *objptr = auxptr + auxlen;
    uint64_t objlen = pheader->totalLength - auxlen;
    
    if (auxlen != 0 && aux != NULL) {
        string_t errbuf;
        CFArrayRef _aux = deserialize(auxptr, auxlen, &errbuf);
        if (_aux == NULL) {
            fprintf(stderr, "Error: %s\n", errbuf.c_str());
            return false;
        }
        *aux = _aux;
    }
    
    if (objlen != 0 && retobj != NULL) {
        *retobj = unarchive(objptr, objlen);
    }
    
    return true;
}

bool test(idevice_connection_t conn) {
    // I'm not sure if this argument is necessary - but Xcode uses it, so I'm using it too.
    CFMutableDictionaryRef capabilities = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    
    int64_t _v1 = 1;
    int64_t _v2 = 2;
    
    CFNumberRef v1 = CFNumberCreate(NULL, kCFNumberSInt64Type, &_v1);
    CFNumberRef v2 = CFNumberCreate(NULL, kCFNumberSInt64Type, &_v2);
    
    CFDictionaryAddValue(capabilities, CFSTR("com.apple.private.DTXBlockCompression"), v2);
    CFDictionaryAddValue(capabilities, CFSTR("com.apple.private.DTXConnection"), v1);
    
    // serialize the dictionary
    message_aux_t args;
    args.append_obj(capabilities);
    
    CFRelease(capabilities);
    CFRelease(v1);
    CFRelease(v2);
    
    if (!send_message(conn, 9, (char *)CFSTR("_notifyOfPublishedCapabilities:"), &args, false)) {
        fprintf(stderr, "Error: failed to receive response from _notifyOfPublishedCapabilities:\n");
        return false;
    }
    
    CFTypeRef obj = NULL;
    CFArrayRef aux = NULL;
    
    if (!recv_message(conn, &obj, &aux) || obj == NULL || aux == NULL) {
        fprintf(stderr, "Error: failed to receive response from _notifyOfPublishedCapabilities:\n");
        return false;
    }
    
    
    bool ok = false;
    do
    {
        if ( CFGetTypeID(obj) != CFStringGetTypeID()
            || to_stlstr((CFStringRef)obj) != "_notifyOfPublishedCapabilities:")
        {
            fprintf(stderr, "Error: unexpected message selector: %s\n", get_description(obj).c_str());
            break;
        }
        
        CFDictionaryRef _channels;
        
        // extract the channel list from the arguments
        if ( CFArrayGetCount(aux) != 1
            || (_channels = (CFDictionaryRef)CFArrayGetValueAtIndex(aux, 0)) == NULL
            || CFGetTypeID(_channels) != CFDictionaryGetTypeID()
            || CFDictionaryGetCount(_channels) == 0 ) {
            fprintf(stderr, "channel list has an unexpected format:\n%s\n", get_description(aux).c_str());
            break;
        }
        
        channels = (CFDictionaryRef)CFRetain(_channels);
        
        if (verbose) {
            printf("channel list:\n%s\n", get_description(channels).c_str());
        }
        
        ok = true;
    }
    while ( false );
    
    CFRelease(obj);
    CFRelease(aux);
    
    return ok;
}


static int make_channel(idevice_connection_t conn, CFStringRef identifier) {
    if ( !CFDictionaryContainsKey(channels, identifier) ) {
        fprintf(stderr, "channel %s is not supported by the server\n", to_stlstr(identifier).c_str());
        return -1;
    }
    
    int code = ++cur_channel;
    
    message_aux_t args;
    args.append_int(code);
    args.append_obj(identifier);
    
    CFTypeRef retobj = NULL;

    if (!send_message(conn, 0, (char *)CFSTR("_requestChannelWithCode:identifier:"), &args, true) || !recv_message(conn, &retobj, NULL)) {
        return -1;
    }
    
    if ( retobj != NULL ) {
        fprintf(stderr, "Error: _requestChannelWithCode:identifier: returned %s\n", get_description(retobj).c_str());
        CFRelease(retobj);
        return -1;
    }
    
    return code;
}

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


//    if ( !send_message(conn, 0, CFSTR("_notifyOfPublishedCapabilities:"), &args, false) )
//        return false;
//
//    CFTypeRef obj = NULL;
//    CFArrayRef aux = NULL;
//
//    // we are now expecting the server to reply with the same message.
//    // a description of all available channels will be provided in the arguments list.
//    if ( !recv_message(conn, &obj, &aux) || obj == NULL || aux == NULL )
//    {
//        fprintf(stderr, "Error: failed to receive response from _notifyOfPublishedCapabilities:\n");
//        return false;
//    }
//
//    bool ok = false;
//    do
//    {
//        if ( CFGetTypeID(obj) != CFStringGetTypeID()
//            || to_stlstr((CFStringRef)obj) != "_notifyOfPublishedCapabilities:" )
//        {
//            fprintf(stderr, "Error: unexpected message selector: %s\n", get_description(obj).c_str());
//            break;
//        }
//
//        CFDictionaryRef _channels;
//
//        // extract the channel list from the arguments
//        if ( CFArrayGetCount(aux) != 1
//            || (_channels = (CFDictionaryRef)CFArrayGetValueAtIndex(aux, 0)) == NULL
//            || CFGetTypeID(_channels) != CFDictionaryGetTypeID()
//            || CFDictionaryGetCount(_channels) == 0 )
//        {
//            fprintf(stderr, "channel list has an unexpected format:\n%s\n", get_description(aux).c_str());
//            break;
//        }
//
//        channels = (CFDictionaryRef)CFRetain(_channels);
//
//        if ( verbose )
//            printf("channel list:\n%s\n", get_description(channels).c_str());
//
//        ok = true;
//    }
//    while ( false );
//
//    CFRelease(obj);
//    CFRelease(aux);
//
//    return ok;
//}

//
//static bool recv_message(am_device_service_connection *conn,
//                         CFTypeRef *retobj,
//                         CFArrayRef *aux)
//{
//    uint32_t id = 0;
//    bytevec_t payload;
//
//    int sock = MobileDevice.AMDServiceConnectionGetSocket(conn);
//
//    while ( true )
//    {
//        DTXMessageHeader mheader;
//        ssize_t nrecv = ssl_enabled
//        ? MobileDevice.AMDServiceConnectionReceive(conn, &mheader, sizeof(mheader))
//        : read(sock, &mheader, sizeof(mheader));
//        if ( nrecv != sizeof(mheader) )
//        {
//            fprintf(stderr, "failed to read message header: %s, nrecv = %lx\n", strerror(errno), nrecv);
//            return false;
//        }
//
//        if ( mheader.magic != 0x1F3D5B79 )
//        {
//            fprintf(stderr, "bad header magic: %x\n", mheader.magic);
//            return false;
//        }
//
//        if ( mheader.conversationIndex == 1 )
//        {
//            // the message is a response to a previous request, so it should have the same id as the request
//            if ( mheader.identifier != cur_message )
//            {
//                fprintf(stderr, "expected response to message id=%d, got a new message with id=%d\n", cur_message, mheader.identifier);
//                return false;
//            }
//        }
//        else if ( mheader.conversationIndex == 0 )
//        {
//            // the message is not a response to a previous request. in this case, different iOS versions produce different results.
//            // on iOS 9, the incoming message can have the same message ID has the previous message we sent to the server.
//            // on later versions, the incoming message will have a new message ID. we must be aware of both situations.
//            if ( mheader.identifier > cur_message )
//            {
//                // new message id, we must update the count on our side
//                cur_message = mheader.identifier;
//            }
//            else if ( mheader.identifier < cur_message )
//            {
//                // the id must match the previous request, anything else doesn't really make sense
//                fprintf(stderr, "unexpected message ID: %d\n", mheader.identifier);
//                return false;
//            }
//        }
//        else
//        {
//            fprintf(stderr, "invalid conversation index: %d\n", mheader.conversationIndex);
//            return false;
//        }
//
//        if ( mheader.fragmentId == 0 )
//        {
//            id = mheader.identifier;
//            // when reading multiple message fragments, the 0th fragment contains only a message header
//            if ( mheader.fragmentCount > 1 )
//                continue;
//        }
//
//        // read the entire payload in the current fragment
//        bytevec_t frag;
//        append_v(frag, &mheader, sizeof(mheader));
//        frag.resize(frag.size() + mheader.length);
//
//        uint8_t *data = frag.data() + sizeof(mheader);
//
//        uint32_t nbytes = 0;
//        while ( nbytes < mheader.length )
//        {
//            uint8_t *curptr = data + nbytes;
//            size_t curlen = mheader.length - nbytes;
//            nrecv = ssl_enabled
//            ? MobileDevice.AMDServiceConnectionReceive(conn, curptr, curlen)
//            : read(sock, curptr, curlen);
//            if ( nrecv <= 0 )
//            {
//                fprintf(stderr, "failed reading from socket: %s\n", strerror(errno));
//                return false;
//            }
//            nbytes += nrecv;
//        }
//
//        // append to the incremental payload
//        append_v(payload, data, mheader.length);
//
//        // done reading message fragments?
//        if ( mheader.fragmentId == mheader.fragmentCount - 1 )
//            break;
//    }
//
//    const DTXMessagePayloadHeader *pheader = (const DTXMessagePayloadHeader *)payload.data();
//
//    // we don't know how to decompress messages yet
//    uint8_t compression = (pheader->flags & 0xFF000) >> 12;
//    if ( compression != 0 )
//    {
//        fprintf(stderr, "message is compressed (compression type %d)\n", compression);
//        return false;
//    }
//
//    // serialized object array is located just after payload header
//    const uint8_t *auxptr = payload.data() + sizeof(DTXMessagePayloadHeader);
//    uint32_t auxlen = pheader->auxiliaryLength;
//
//    // archived payload object appears after the auxiliary array
//    const uint8_t *objptr = auxptr + auxlen;
//    uint64_t objlen = pheader->totalLength - auxlen;
//
//    if ( auxlen != 0 && aux != NULL )
//    {
//        string_t errbuf;
//        CFArrayRef _aux = deserialize(auxptr, auxlen, &errbuf);
//        if ( _aux == NULL )
//        {
//            fprintf(stderr, "Error: %s\n", errbuf.c_str());
//            return false;
//        }
//        *aux = _aux;
//    }
//
//    if ( objlen != 0 && retobj != NULL )
//        *retobj = unarchive(objptr, objlen);
//
//    return true;
//}
//
////-----------------------------------------------------------------------------
//// perform the initial client-server handshake.
//// here we retrieve the list of available channels published by the instruments server.
//// we can open a given channel with make_channel().
//static bool perform_handshake(am_device_service_connection *conn)
//{
//    // I'm not sure if this argument is necessary - but Xcode uses it, so I'm using it too.
//    CFMutableDictionaryRef capabilities = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
//
//    int64_t _v1 = 1;
//    int64_t _v2 = 2;
//
//    CFNumberRef v1 = CFNumberCreate(NULL, kCFNumberSInt64Type, &_v1);
//    CFNumberRef v2 = CFNumberCreate(NULL, kCFNumberSInt64Type, &_v2);
//
//    CFDictionaryAddValue(capabilities, CFSTR("com.apple.private.DTXBlockCompression"), v2);
//    CFDictionaryAddValue(capabilities, CFSTR("com.apple.private.DTXConnection"), v1);
//
//    // serialize the dictionary
//    message_aux_t args;
//    args.append_obj(capabilities);
//
//    CFRelease(capabilities);
//    CFRelease(v1);
//    CFRelease(v2);
//
//    if ( !send_message(conn, 0, CFSTR("_notifyOfPublishedCapabilities:"), &args, false) )
//        return false;
//
//    CFTypeRef obj = NULL;
//    CFArrayRef aux = NULL;
//
//    // we are now expecting the server to reply with the same message.
//    // a description of all available channels will be provided in the arguments list.
//    if ( !recv_message(conn, &obj, &aux) || obj == NULL || aux == NULL )
//    {
//        fprintf(stderr, "Error: failed to receive response from _notifyOfPublishedCapabilities:\n");
//        return false;
//    }
//
//    bool ok = false;
//    do
//    {
//        if ( CFGetTypeID(obj) != CFStringGetTypeID()
//            || to_stlstr((CFStringRef)obj) != "_notifyOfPublishedCapabilities:" )
//        {
//            fprintf(stderr, "Error: unexpected message selector: %s\n", get_description(obj).c_str());
//            break;
//        }
//
//        CFDictionaryRef _channels;
//
//        // extract the channel list from the arguments
//        if ( CFArrayGetCount(aux) != 1
//            || (_channels = (CFDictionaryRef)CFArrayGetValueAtIndex(aux, 0)) == NULL
//            || CFGetTypeID(_channels) != CFDictionaryGetTypeID()
//            || CFDictionaryGetCount(_channels) == 0 )
//        {
//            fprintf(stderr, "channel list has an unexpected format:\n%s\n", get_description(aux).c_str());
//            break;
//        }
//
//        channels = (CFDictionaryRef)CFRetain(_channels);
//
//        if ( verbose )
//            printf("channel list:\n%s\n", get_description(channels).c_str());
//
//        ok = true;
//    }
//    while ( false );
//
//    CFRelease(obj);
//    CFRelease(aux);
//
//    return ok;
//}
//
////-----------------------------------------------------------------------------
//// establish a connection to a service in the instruments server process.
//// the channel identifier should be in the list of channels returned by the server
//// in perform_handshake(). after a channel is established, you can use send_message()
//// to remotely invoke Objective-C methods.
//static int make_channel(am_device_service_connection *conn, CFStringRef identifier)
//{
//    if ( !CFDictionaryContainsKey(channels, identifier) )
//    {
//        fprintf(stderr, "channel %s is not supported by the server\n", to_stlstr(identifier).c_str());
//        return -1;
//    }
//
//    int code = ++cur_channel;
//
//    message_aux_t args;
//    args.append_int(code);
//    args.append_obj(identifier);
//
//    CFTypeRef retobj = NULL;
//
//    // request to open the channel, expect an empty reply
//    if ( !send_message(conn, 0, CFSTR("_requestChannelWithCode:identifier:"), &args)
//        || !recv_message(conn, &retobj, NULL) )
//    {
//        return -1;
//    }
//
//    if ( retobj != NULL )
//    {
//        fprintf(stderr, "Error: _requestChannelWithCode:identifier: returned %s\n", get_description(retobj).c_str());
//        CFRelease(retobj);
//        return -1;
//    }
//
//    return code;
//}



// 意外发现的服务。
//"com.apple.dt.Instruments.inlineCapabilities" = 1;
//"com.apple.dt.Xcode.WatchProcessControl" = 3;
//"com.apple.dt.services.capabilities.vmtracking" = 1;
//"com.apple.instruments.server.services.ConditionInducer" = 1;
//"com.apple.instruments.server.services.LocationSimulation" = 1;
//"com.apple.instruments.server.services.activitytracetap" = 6;
//"com.apple.instruments.server.services.activitytracetap.deferred" = 1;
//"com.apple.instruments.server.services.activitytracetap.immediate" = 1;
//"com.apple.instruments.server.services.activitytracetap.windowed" = 1;
//"com.apple.instruments.server.services.assets" = 4;
//"com.apple.instruments.server.services.assets.response" = 2;
//"com.apple.instruments.server.services.coreml.modelwriter" = 1;
//"com.apple.instruments.server.services.coreml.perfrunner" = 1;
//"com.apple.instruments.server.services.coreprofilesessiontap" = 2;
//"com.apple.instruments.server.services.coreprofilesessiontap.config" = 1;
//"com.apple.instruments.server.services.coreprofilesessiontap.deferred" = 1;
//"com.apple.instruments.server.services.coreprofilesessiontap.immediate" = 1;
//"com.apple.instruments.server.services.coreprofilesessiontap.multipleTimeTriggers" = 1;
//"com.apple.instruments.server.services.coreprofilesessiontap.pmc" = 2;
//"com.apple.instruments.server.services.coreprofilesessiontap.pmi" = 2;
//"com.apple.instruments.server.services.coreprofilesessiontap.windowed" = 1;
//"com.apple.instruments.server.services.coresampling" = 10;
//"com.apple.instruments.server.services.device.applictionListing" = 1;
//"com.apple.instruments.server.services.device.xpccontrol" = 2;
//"com.apple.instruments.server.services.deviceinfo" = 113;
//"com.apple.instruments.server.services.deviceinfo.app-life-cycle" = 1;
//"com.apple.instruments.server.services.deviceinfo.condition-inducer" = 1;
//"com.apple.instruments.server.services.deviceinfo.devicesymbolication" = 1;
//"com.apple.instruments.server.services.deviceinfo.dyld-tracing" = 1;
//"com.apple.instruments.server.services.deviceinfo.energytracing.location" = 1;
//"com.apple.instruments.server.services.deviceinfo.gcd-perf" = 1;
//"com.apple.instruments.server.services.deviceinfo.gpu-allocation" = 1;
//"com.apple.instruments.server.services.deviceinfo.metal" = 1;
//"com.apple.instruments.server.services.deviceinfo.recordOptions" = 1;
//"com.apple.instruments.server.services.deviceinfo.scenekit-tracing" = 1;
//"com.apple.instruments.server.services.deviceinfo.systemversion" = 160100;
//"com.apple.instruments.server.services.filetransfer" = 1;
//"com.apple.instruments.server.services.filetransfer.debuginbox" = 1;
//"com.apple.instruments.server.services.gpu" = 1;
//"com.apple.instruments.server.services.gpu.counters" = 4;
//"com.apple.instruments.server.services.gpu.counters.multisources" = 1;
//"com.apple.instruments.server.services.gpu.deferred" = 1;
//"com.apple.instruments.server.services.gpu.immediate" = 1;
//"com.apple.instruments.server.services.gpu.performancestate" = 2;
//"com.apple.instruments.server.services.gpu.shaderprofiler" = 1;
//"com.apple.instruments.server.services.graphics.coreanimation" = 1;
//"com.apple.instruments.server.services.graphics.coreanimation.deferred" = 1;
//"com.apple.instruments.server.services.graphics.coreanimation.immediate" = 1;
//"com.apple.instruments.server.services.graphics.opengl" = 1;
//"com.apple.instruments.server.services.graphics.opengl.deferred" = 1;
//"com.apple.instruments.server.services.graphics.opengl.immediate" = 1;
//"com.apple.instruments.server.services.httparchiverecording" = 2;
//"com.apple.instruments.server.services.mobilenotifications" = 2;
//"com.apple.instruments.server.services.networking" = 2;
//"com.apple.instruments.server.services.networking.deferred" = 1;
//"com.apple.instruments.server.services.networking.immediate" = 1;
//"com.apple.instruments.server.services.objectalloc" = 5;
//"com.apple.instruments.server.services.objectalloc.deferred" = 1;
//"com.apple.instruments.server.services.objectalloc.immediate" = 1;
//"com.apple.instruments.server.services.objectalloc.zombies" = 1;
//"com.apple.instruments.server.services.processcontrol" = 107;
//"com.apple.instruments.server.services.processcontrol.capability.memorylimits" = 1;
//"com.apple.instruments.server.services.processcontrol.capability.signal" = 1;
//"com.apple.instruments.server.services.processcontrol.feature.deviceio" = 103;
//"com.apple.instruments.server.services.processcontrolbydictionary" = 4;
//"com.apple.instruments.server.services.remoteleaks" = 9;
//"com.apple.instruments.server.services.remoteleaks.deferred" = 1;
//"com.apple.instruments.server.services.remoteleaks.immediate" = 1;
//"com.apple.instruments.server.services.sampling" = 11;
//"com.apple.instruments.server.services.sampling.deferred" = 1;
//"com.apple.instruments.server.services.sampling.immediate" = 1;
//"com.apple.instruments.server.services.screenshot" = 2;
//"com.apple.instruments.server.services.storekit" = 4;
//"com.apple.instruments.server.services.sysmontap" = 3;
//"com.apple.instruments.server.services.sysmontap.deferred" = 1;
//"com.apple.instruments.server.services.sysmontap.immediate" = 1;
//"com.apple.instruments.server.services.sysmontap.processes" = 1;
//"com.apple.instruments.server.services.sysmontap.system" = 1;
//"com.apple.instruments.server.services.sysmontap.windowed" = 1;
//"com.apple.instruments.server.services.ultraviolet.agent-pipe" = 1;
//"com.apple.instruments.server.services.ultraviolet.preview" = 1;
//"com.apple.instruments.server.services.ultraviolet.renderer" = 1;
//"com.apple.instruments.server.services.vmtracking" = 1;
//"com.apple.instruments.server.services.vmtracking.deferred" = 1;
//"com.apple.instruments.server.services.vmtracking.immediate" = 1;
//"com.apple.instruments.target.ios" = 160100;
//"com.apple.instruments.target.logical-cpus" = 6;
//"com.apple.instruments.target.mtb.denom" = 3;
//"com.apple.instruments.target.mtb.numer" = 125;
//"com.apple.instruments.target.physical-cpus" = 6;
//"com.apple.instruments.target.user-page-size" = 16384;
//"com.apple.private.DTXBlockCompression" = 2;
//"com.apple.private.DTXConnection" = 1;
//"com.apple.xcode.debug-gauge-data-providers.Energy" = 1;
//"com.apple.xcode.debug-gauge-data-providers.NetworkStatistics" = 1;
//"com.apple.xcode.debug-gauge-data-providers.SceneKit" = 1;
//"com.apple.xcode.debug-gauge-data-providers.SpriteKit" = 1;
//"com.apple.xcode.debug-gauge-data-providers.procinfo" = 1;
//"com.apple.xcode.debug-gauge-data-providers.resources" = 1;
//"com.apple.xcode.resource-control" = 1;
