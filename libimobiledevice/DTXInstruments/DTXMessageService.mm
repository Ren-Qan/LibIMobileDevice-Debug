//
//  DTXMessageManager.cpp
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/19.
//

#include "DTXMessageService.hh"

static bool verbose = false;

static int cur_channel = 0;
static int cur_message = 0;

static CFDictionaryRef channels = NULL;

bool send_message(idevice_connection_t conn,
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


bool recv_message(idevice_connection_t conn,
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

int make_channel(idevice_connection_t conn,
                 CFStringRef identifier) {
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


bool hand_shake(idevice_connection_t conn) {
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
