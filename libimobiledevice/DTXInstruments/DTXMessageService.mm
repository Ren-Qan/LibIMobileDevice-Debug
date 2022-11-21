//
//  DTXMessageManager.cpp
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/19.
//

#include "DTXMessageService.hh"

#include <libimobiledevice/lockdown.h>
#include <libimobiledevice/mobile_image_mounter.h>
#include <libimobiledevice/service.h>

#define REMOTESERVER_SERVICE_NAME "com.apple.instruments.remoteserver.DVTSecureSocketProxy"

static bool verbose = false;

static int cur_channel_tag = 0;
static int cur_message = 0;

static CFDictionaryRef channels = NULL;
static instruments_cb_t instruments_datas_call_back = NULL;

bool hand_shake(idevice_connection_t conn);

char * idevice_get_version(idevice_t _Nullable device) {
    if (device == NULL) {
        return NULL;
    }
    
    char *s_version = NULL;
    
    lockdownd_client_t client_loc = NULL;
    lockdownd_client_new(device, &client_loc, "getVersion");
    
    plist_t p_version = NULL;
    if (lockdownd_get_value(client_loc, NULL, "ProductVersion", &p_version) == LOCKDOWN_E_SUCCESS) {
        plist_get_string_val(p_version, &s_version);
    }
    
    lockdownd_client_free(client_loc);
    plist_free(p_version);
    return s_version;
}

char * find_image_path(idevice_t device) {
    char * version = idevice_get_version(device);
    if (version == NULL) {
        return NULL;
    }
    
    const char *path = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/";
    const char *fileName = "/DeveloperDiskImage.dmg";
    
    int len = (int)(strlen(version) + strlen(path) + strlen(fileName) + 1);
    char * result = (char *)malloc(sizeof(char) * len);
    
    strcat(result, path);
    strcat(result, version);
    strcat(result, fileName);
    
    return result;
}

static ssize_t upload_mounter_callback(void* buffer, size_t length, void *user_data) {
    return 0;
}

static int32_t constructor_remote_service(idevice_t device, lockdownd_service_descriptor_t service, idevice_connection_t * conn) {
    if (!device || !service || service -> port == 0) {
        return SERVICE_E_INVALID_ARG;
    }
    
    // connect
    idevice_connection_t connection;
    idevice_error_t error = idevice_connect(device, service -> port, &connection);
    if (error != IDEVICE_E_SUCCESS) {
        return error;
    };
    
    int fd;
    error = idevice_connection_get_fd(connection, &fd);
    if (error != IDEVICE_E_SUCCESS) {
        return error;
    }
    
    if (service -> ssl_enabled) {
        idevice_connection_enable_ssl(connection);
    }
    
    if (!hand_shake(connection)) {
        return SERVICE_E_START_SERVICE_ERROR;
    }
    
    (*conn) = connection;
    
    return SERVICE_E_SUCCESS;
}

bool send_message(idevice_connection_t conn,
                  int channel,
                  char * selector,
                  const message_aux_t *args,
                  bool expects_reply) {
    uint32_t id = ++cur_message;
    
    bytevec_t aux;
    if (args != NULL) {
        args->get_bytes(&aux);
    }
    
    bytevec_t sel;
    if (selector != NULL) {
        archive(&sel, selector);
    }
    
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
    uint32_t channelCode = 0;
    uint32_t identifier = 0;
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
            identifier = mheader.identifier;
            channelCode = mheader.channelCode;
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
        if (instruments_datas_call_back != NULL) {
            instruments_datas_call_back(channelCode, (void *)&_aux);
        }
    }
    
    
    if (objlen != 0 && retobj != NULL) {
        *retobj = unarchive(objptr, objlen);
        if (instruments_datas_call_back != NULL) {
            instruments_datas_call_back(channelCode, (void *)retobj);
        }
    }
    
    return true;
}

instruments_error instruments_start_connection(idevice_t device,
                                               idevice_connection_t * conn,
                                               instruments_cb_t call_back) {
    if (device == NULL) {
        return -10;
    }
    
    mobile_image_mounter_client_t client;
    *conn = NULL;
    
    // start mounter service
    int error = mobile_image_mounter_start_service(device, &client, "IN_STRUMENTS");
    if (error != 0) {
        return -11;
    }
    
    // look up mounter image signature
    plist_t mounter_lookup_result;
    if (mobile_image_mounter_lookup_image(client, "Developer", &mounter_lookup_result) != 0) {
        mobile_image_mounter_free(client);
        return -12;
    }
    
    plist_t signatureDic = plist_dict_get_item(mounter_lookup_result, "ImageSignature");
    plist_t signatureArr = plist_array_get_item(signatureDic, 0);
    
    char *signatureString;
    uint64_t signtureLen;
    plist_get_data_val(signatureArr, &signatureString, &signtureLen);
    
    plist_free(signatureDic);
    
    if (signtureLen <= 0 || signatureString == NULL) {
        mobile_image_mounter_free(client);
        return -13;
    }
    
    free(signatureString);
    
    // upload image
    if (mobile_image_mounter_upload_image(client, "Developer", 9, signatureString, (uint16_t)signtureLen, upload_mounter_callback, NULL) != 0) {
        mobile_image_mounter_free(client);
        return -14;
    }
    
    // get imagePath
    char * image_path = find_image_path(device);
    if (image_path == NULL) {
        mobile_image_mounter_free(client);
        return -15;
    }
    
    plist_t result = NULL;
    if (mobile_image_mounter_mount_image(client, image_path, signatureString, signtureLen, "Developer", &result) != 0) {
        mobile_image_mounter_free(client);
        free(image_path);
        return -16;
    }
    
    free(image_path);
    
    // service start
    int32_t reomoteError = 0;
    if (service_client_factory_start_service(device, REMOTESERVER_SERVICE_NAME, (void **)(conn), "Remote", SERVICE_CONSTRUCTOR(constructor_remote_service), &reomoteError) != 0) {
        mobile_image_mounter_free(client);
        return -17;
    }
    instruments_datas_call_back = call_back;
    mobile_image_mounter_free(client);
    return 0;
}

void instrument_connection_free(idevice_connection_t conn) {
    instruments_datas_call_back = NULL;
    if (conn == NULL) {
        return;
    }
    idevice_disconnect(conn);
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

int instrument_make_channel(idevice_connection_t conn,
                            CFStringRef identifier) {
    if (channels == NULL) {
        return -1;
    }
    
    if ( !CFDictionaryContainsKey(channels, identifier) ) {
        fprintf(stderr, "channel %s is not supported by the server\n", to_stlstr(identifier).c_str());
        return -1;
    }
    
    int code = ++cur_channel_tag;
    
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

bool instruments_response(idevice_connection_t conn,
                          int channel_code,
                          char *selector,
                          const message_aux_t * aux) {
    if (channel_code < 0 || channel_code > cur_channel_tag) {
        return false;
    }
    
    CFTypeRef retobj = NULL;
    CFArrayRef retArr = NULL;
    
    bool state = send_message(conn, channel_code, selector, aux, true);
    state = state & recv_message(conn, &retobj, &retArr);
    if (retobj != NULL) {
        CFRelease(retobj);
    }
    
    if (retArr != NULL) {
        CFRelease(retArr);
    }
    
    return state;
}

void instrument_receive(idevice_connection_t conn) {
    CFTypeRef retobj = NULL;
    CFArrayRef retArr = NULL;
    
    recv_message(conn, &retobj, &retArr);
    
    if (retobj != NULL) {
        CFRelease(retobj);
    }
    
    if (retArr != NULL) {
        CFRelease(retArr);
    }
    
    return;
}
