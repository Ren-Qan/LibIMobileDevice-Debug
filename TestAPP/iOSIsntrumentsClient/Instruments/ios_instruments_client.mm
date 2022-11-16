#include "ios_instruments_client.h"
#include "mobile_device.hpp"
#include <unistd.h>

static string_t device_id;              // user's preferred device (-d option)
static bool found_device = false;       // has the user's preferred device been detected?
static bool verbose = false;            // verbose mode (-v option)
static int cur_message = 0;             // current message id
static int cur_channel = 0;             // current channel id
static CFDictionaryRef channels = NULL; // list of available channels published by the instruments server
static int pid2kill = -1;               // process id to kill ("kill" option)
static const char *bid2launch = NULL;   // bundle id of app to launch ("launch" option)
static bool proclist = true;           // print the process list ("proclist" option)
static bool applist = false;            // print the application list ("applist" option)
static bool ssl_enabled = false;        // does the instruments server use SSL?

//-----------------------------------------------------------------------------
void message_aux_t::append_int(int32_t val)
{
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 3);   // 32-bit int
    append_d(buf, val);
}

//-----------------------------------------------------------------------------
void message_aux_t::append_long(int64_t val)
{
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 4);   // 64-bit int
    append_q(buf, val);
}

//-----------------------------------------------------------------------------
void message_aux_t::append_obj(CFTypeRef obj)
{
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 2);   // archived object
    
    bytevec_t tmp;
    archive(&tmp, obj);
    
    append_d(buf, tmp.size());
    append_b(buf, tmp);
}

//-----------------------------------------------------------------------------
void message_aux_t::get_bytes(bytevec_t *out) const
{
    if ( !buf.empty() )
    {
        // the final serialized array must start with a magic qword,
        // followed by the total length of the array data as a qword,
        // followed by the array data itself.
        append_q(*out, 0x1F0);
        append_q(*out, buf.size());
        append_b(*out, buf);
    }
}

//-----------------------------------------------------------------------------
// callback that handles device notifications. called once for each connected device.
static void device_callback(am_device_notification_callback_info *cbi, void *arg)
{
    if ( cbi->code != ADNCI_MSG_CONNECTED )
        return;
    
    CFStringRef id = MobileDevice.AMDeviceCopyDeviceIdentifier(cbi->dev);
    string_t _device_id = to_stlstr(id);
    CFRelease(id);
    
    if ( !device_id.empty() && device_id != _device_id )
        return;
    
    found_device = true;
    
    if ( verbose )
        printf("found device: %s\n", _device_id.c_str());
    
    do
    {
        // start a session on the device
        if ( MobileDevice.AMDeviceConnect(cbi->dev) != kAMDSuccess
            || MobileDevice.AMDeviceIsPaired(cbi->dev) == 0
            || MobileDevice.AMDeviceValidatePairing(cbi->dev) != kAMDSuccess
            || MobileDevice.AMDeviceStartSession(cbi->dev) != kAMDSuccess )
        {
            fprintf(stderr, "Error: failed to start a session on the device\n");
            break;
        }
        
        am_device_service_connection **connptr = (am_device_service_connection **)arg;
        
        // launch the instruments server
        mach_error_t err = MobileDevice.AMDeviceSecureStartService(
                                                                   cbi->dev,
                                                                   CFSTR("com.apple.instruments.remoteserver"),
                                                                   NULL,
                                                                   connptr);
        
        if ( err != kAMDSuccess )
        {
            // try again with an SSL-enabled service, commonly used after iOS 14
            err = MobileDevice.AMDeviceSecureStartService(
                                                          cbi->dev,
                                                          CFSTR("com.apple.instruments.remoteserver.DVTSecureSocketProxy"),
                                                          NULL,
                                                          connptr);
            
            if ( err != kAMDSuccess )
            {
                fprintf(stderr, "Failed to start the instruments server (0x%x). "
                        "Perhaps DeveloperDiskImage.dmg is not installed on the device?\n", err);
                break;
            }
            
            ssl_enabled = true;
        }
        
        if ( verbose )
            printf("successfully launched instruments server\n");
    }
    while ( false );
    
    MobileDevice.AMDeviceStopSession(cbi->dev);
    MobileDevice.AMDeviceDisconnect(cbi->dev);
    
    CFRunLoopStop(CFRunLoopGetCurrent());
}

//-----------------------------------------------------------------------------
// launch the instruments server on the user's device.
// returns a handle that can be used to send/receive data to/from the server.
static am_device_service_connection *start_server(void)
{
    am_device_notification *notify_handle = NULL;
    am_device_service_connection *conn = NULL;
    
    mach_error_t err = MobileDevice.AMDeviceNotificationSubscribe(
                                                                  device_callback,
                                                                  0,
                                                                  0,
                                                                  &conn,
                                                                  &notify_handle);
    
    if ( err != kAMDSuccess )
    {
        fprintf(stderr, "failed to register device notifier: 0x%x\n", err);
        return NULL;
    }
    
    // start a run loop, and wait for the device notifier to call our callback function.
    // if no device was detected within 3 seconds, we bail out.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 3, false);
    
    MobileDevice.AMDeviceNotificationUnsubscribe(notify_handle);
    
    if ( conn == NULL && !found_device )
    {
        if ( device_id.empty() )
            fprintf(stderr, "Failed to find a connected device\n");
        else
            fprintf(stderr, "Failed to find device with id = %s\n", device_id.c_str());
        return NULL;
    }
    
    return conn;
}

//-----------------------------------------------------------------------------
// "call" an Objective-C method in the instruments server process
//   conn           server handle
//   channel        determines the object that will receive the message,
//                  obtained by a previous call to make_channel()
//   selector       method name
//   args           serialized list of arguments for the method
//   expects_reply  do we expect a return value from the method?
//                  the return value can be obtained by a subsequent call to recv_message()
static bool send_message(
                         am_device_service_connection *conn,
                         int channel,
                         CFStringRef selector,
                         const message_aux_t *args,
                         bool expects_reply = true)
{
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
    pheader.auxiliaryLength = aux.size();
    pheader.totalLength = aux.size() + sel.size();
    
    DTXMessageHeader mheader;
    mheader.magic = 0x1F3D5B79;
    mheader.cb = sizeof(DTXMessageHeader);
    mheader.fragmentId = 0;
    mheader.fragmentCount = 1;
    mheader.length = sizeof(pheader) + pheader.totalLength;
    mheader.identifier = id;
    mheader.conversationIndex = 0;
    mheader.channelCode = channel;
    mheader.expectsReply = (expects_reply ? 1 : 0);
    
    bytevec_t msg;
    append_v(msg, &mheader, sizeof(mheader));
    append_v(msg, &pheader, sizeof(pheader));
    append_b(msg, aux);
    append_b(msg, sel);
    
    size_t msglen = msg.size();
    ssize_t nsent = ssl_enabled
    ? MobileDevice.AMDServiceConnectionSend(conn, msg.data(), msglen)
    : write(MobileDevice.AMDServiceConnectionGetSocket(conn), msg.data(), msglen);
    if ( nsent != msglen )
    {
        fprintf(stderr, "Failed to send 0x%lx bytes of message: %s\n", msglen, strerror(errno));
        return false;
    }
    
    return true;
}

//-----------------------------------------------------------------------------
//        前32个字节(两行) 为DTXMessage的头部 (包含了消息的类型和请求的channel)
//        后面是携带的payload
//        Returns:
//            DTXMessageHeader, payload
//
//        Raises:
//            MuxError
//        Returns:
//            retobj  contains the return value for the method invoked by send_message()
//            aux     usually empty, except in specific situations (see _notifyOfPublishedCapabilities)
//
//        # Refs: https://github.com/troybowman/dtxmsg/blob/master/dtxmsg_client.cpp
//        数据解析说明
//        >> 全部数据
//        00000000: 79 5B 3D 1F 20 00 00 00  00 00 01 00 2C 1C 00 00  y[=. .......,...
//        00000010: 02 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................
//        00000020: 02 00 00 00 71 1B 00 00  1C 1C 00 00 00 00 00 00  ....q...........
//        00000030: F0 1B 00 00 00 00 00 00  61 1B 00 00 00 00 00 00  ........a.......
//        00000040: 0A 00 00 00 02 00 00 00  55 1B 00 00 62 70 6C 69  ........U...bpli
//        00000050: 73 74 30 30 D4 00 01 00  02 00 03 00 04 00 05 00  st00............
//        00000060: 06 01 2F 01 30 58 24 76  65 72 73 69 6F 6E 58 24  ../.0X$versionX$
//        00000070: 6F 62 6A 65 63 74 73 59
//        >> 前32个字节
//        00000000: 79 5B 3D 1F 20 00 00 00  00 00 01 00 2C 1C 00 00  y[=. .......,...
//        00000010: 02 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
//        \\\\
//        struct DTXMessageHeader {
//            u32 magic  # 79 5B 3D 1F
//            u32 cb # 20 00 00 00      # sizeof(DTXMessageHeader)
//            u16 fragmentId # 00 00
//            u16 fragmentCount # 01 00
//            u32 length # 2C 1C 00 00  # 不包括MessageHeader自身的长度
//            u32 messageId # 02 00 00 00
//            u32 conversationIndex # 00 00 00 00 # 1 indicate a reply message
//            u32 channelCode # 00 00 00 00
//            u32 expectReply # 00 00 00 00    # 1 or 0
//        }
//
//        00000020: 02 00 00 00 71 1B 00 00  1C 1C 00 00 00 00 00 00
//        \\\\
//        # 紧跟在MessageHeader的后面
//        struct payloadHeader {
//            u32 flags # 02 00 00 00 # 02(包含两个值), 00(empty), 01,03,04(只有一个值)
//            u32 auxiliaryLength # 71 1B 00 00
//            u64 totalLength # 1C 1C 00 00 00 00 00 00
//        }
//
//        >> Body 部分
//        00000030: F0 1B 00 00 00 00 00 00  61 1B 00 00 00 00 00 00  ........a.......
//        \\\\
//        # 前面8个字节 0X1BF0 据说是Magic word
//        # 后面的 0x1B61 是整个序列化数据的长度
//        # 解析的时候可以直接跳过这部分
//        # 序列化的数据部分, 使用OC的NSKeyedArchiver序列化
//        # 0A,00,00,00: 起始头
//        # 02,00,00,00: 2(obj) 3(u32) 4(u64) 5(u32) 6(u64)
//        # 55,1B,00,00: 序列化的数据长度
//        00000040: 0A 00 00 00 02 00 00 00  55 1B 00 00 62 70 6C 69  ........U...bpli
//        .....
//        # 最后面还跟了一个NSKeyedArchiver序列化后的数据，没有长度字段
//                          objectsY
//
//        ## 空数据Example, 仅用来应答收到的意思。其中的messageId需要跟请求的messageId保持一致
//        00000000: 79 5B 3D 1F 20 00 00 00  00 00 01 00 10 00 00 00  y[=. ...........
//        00000010: 03 00 00 00 01 00 00 00  00 00 00 00 00 00 00 00  ................
//        00000020: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................

// handle a response from the server.
//   conn    server handle
//   retobj  contains the return value for the method invoked by send_message()
//   aux     usually empty, except in specific situations (see _notifyOfPublishedCapabilities)
static bool recv_message(
                         am_device_service_connection *conn,
                         CFTypeRef *retobj,
                         CFArrayRef *aux)
{
    uint32_t id = 0;
    bytevec_t payload;
    
    int sock = MobileDevice.AMDServiceConnectionGetSocket(conn);
    
    while ( true )
    {
        DTXMessageHeader mheader;
        ssize_t nrecv = ssl_enabled
        ? MobileDevice.AMDServiceConnectionReceive(conn, &mheader, sizeof(mheader))
        : read(sock, &mheader, sizeof(mheader));
        if ( nrecv != sizeof(mheader) )
        {
            fprintf(stderr, "failed to read message header: %s, nrecv = %lx\n", strerror(errno), nrecv);
            return false;
        }
        
        if ( mheader.magic != 0x1F3D5B79 )
        {
            fprintf(stderr, "bad header magic: %x\n", mheader.magic);
            return false;
        }
        
        if ( mheader.conversationIndex == 1 )
        {
            // the message is a response to a previous request, so it should have the same id as the request
            if ( mheader.identifier != cur_message )
            {
                fprintf(stderr, "expected response to message id=%d, got a new message with id=%d\n", cur_message, mheader.identifier);
                return false;
            }
        }
        else if ( mheader.conversationIndex == 0 )
        {
            // the message is not a response to a previous request. in this case, different iOS versions produce different results.
            // on iOS 9, the incoming message can have the same message ID has the previous message we sent to the server.
            // on later versions, the incoming message will have a new message ID. we must be aware of both situations.
            if ( mheader.identifier > cur_message )
            {
                // new message id, we must update the count on our side
                cur_message = mheader.identifier;
            }
            else if ( mheader.identifier < cur_message )
            {
                // the id must match the previous request, anything else doesn't really make sense
                fprintf(stderr, "unexpected message ID: %d\n", mheader.identifier);
                return false;
            }
        }
        else
        {
            fprintf(stderr, "invalid conversation index: %d\n", mheader.conversationIndex);
            return false;
        }
        
        if ( mheader.fragmentId == 0 )
        {
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
        while ( nbytes < mheader.length )
        {
            uint8_t *curptr = data + nbytes;
            size_t curlen = mheader.length - nbytes;
            nrecv = ssl_enabled
            ? MobileDevice.AMDServiceConnectionReceive(conn, curptr, curlen)
            : read(sock, curptr, curlen);
            if ( nrecv <= 0 )
            {
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
    if ( compression != 0 )
    {
        fprintf(stderr, "message is compressed (compression type %d)\n", compression);
        return false;
    }
    
    // serialized object array is located just after payload header
    const uint8_t *auxptr = payload.data() + sizeof(DTXMessagePayloadHeader);
    uint32_t auxlen = pheader->auxiliaryLength;
    
    // archived payload object appears after the auxiliary array
    const uint8_t *objptr = auxptr + auxlen;
    uint64_t objlen = pheader->totalLength - auxlen;
    
    if ( auxlen != 0 && aux != NULL )
    {
        string_t errbuf;
        CFArrayRef _aux = deserialize(auxptr, auxlen, &errbuf);
        if ( _aux == NULL )
        {
            fprintf(stderr, "Error: %s\n", errbuf.c_str());
            return false;
        }
        *aux = _aux;
    }
    
    if ( objlen != 0 && retobj != NULL )
        *retobj = unarchive(objptr, objlen);
    
    return true;
}

//-----------------------------------------------------------------------------
// perform the initial client-server handshake.
// here we retrieve the list of available channels published by the instruments server.
// we can open a given channel with make_channel().
static bool perform_handshake(am_device_service_connection *conn)
{
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
    
    if ( !send_message(conn, 0, CFSTR("_notifyOfPublishedCapabilities:"), &args, false) )
        return false;
    
    CFTypeRef obj = NULL;
    CFArrayRef aux = NULL;
    
    // we are now expecting the server to reply with the same message.
    // a description of all available channels will be provided in the arguments list.
    if ( !recv_message(conn, &obj, &aux) || obj == NULL || aux == NULL )
    {
        fprintf(stderr, "Error: failed to receive response from _notifyOfPublishedCapabilities:\n");
        return false;
    }
    
    bool ok = false;
    do
    {
        if ( CFGetTypeID(obj) != CFStringGetTypeID()
            || to_stlstr((CFStringRef)obj) != "_notifyOfPublishedCapabilities:" )
        {
            fprintf(stderr, "Error: unexpected message selector: %s\n", get_description(obj).c_str());
            break;
        }
        
        CFDictionaryRef _channels;
        
        // extract the channel list from the arguments
        if ( CFArrayGetCount(aux) != 1
            || (_channels = (CFDictionaryRef)CFArrayGetValueAtIndex(aux, 0)) == NULL
            || CFGetTypeID(_channels) != CFDictionaryGetTypeID()
            || CFDictionaryGetCount(_channels) == 0 )
        {
            fprintf(stderr, "channel list has an unexpected format:\n%s\n", get_description(aux).c_str());
            break;
        }
        
        channels = (CFDictionaryRef)CFRetain(_channels);
        
        if ( verbose )
            printf("channel list:\n%s\n", get_description(channels).c_str());
        
        ok = true;
    }
    while ( false );
    
    CFRelease(obj);
    CFRelease(aux);
    
    return ok;
}

//-----------------------------------------------------------------------------
// establish a connection to a service in the instruments server process.
// the channel identifier should be in the list of channels returned by the server
// in perform_handshake(). after a channel is established, you can use send_message()
// to remotely invoke Objective-C methods.
static int make_channel(am_device_service_connection *conn, CFStringRef identifier)
{
    if ( !CFDictionaryContainsKey(channels, identifier) )
    {
        fprintf(stderr, "channel %s is not supported by the server\n", to_stlstr(identifier).c_str());
        return -1;
    }
    
    int code = ++cur_channel;
    
    message_aux_t args;
    args.append_int(code);
    args.append_obj(identifier);
    
    CFTypeRef retobj = NULL;
    
    // request to open the channel, expect an empty reply
    if ( !send_message(conn, 0, CFSTR("_requestChannelWithCode:identifier:"), &args)
        || !recv_message(conn, &retobj, NULL) )
    {
        return -1;
    }
    
    if ( retobj != NULL )
    {
        fprintf(stderr, "Error: _requestChannelWithCode:identifier: returned %s\n", get_description(retobj).c_str());
        CFRelease(retobj);
        return -1;
    }
    
    return code;
}

//-----------------------------------------------------------------------------
// invoke method -[DTDeviceInfoService runningProcesses]
//   args:    none
//   returns: CFArrayRef procs
static bool print_proclist(am_device_service_connection *conn)
{
    int channel = make_channel(conn, CFSTR("com.apple.instruments.server.services.deviceinfo"));
    if ( channel < 0 )
        return false;
    
    CFTypeRef retobj = NULL;
    
    if ( !send_message(conn, channel, CFSTR("runningProcesses"), NULL)
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
    }
    else
    {
        fprintf(stderr, "Error: process list is not in the expected format: %s\n", get_description(retobj).c_str());
        ok = false;
    }
    
    CFRelease(retobj);
    return ok;
}

//-----------------------------------------------------------------------------
// invoke method -[DTApplicationListingService installedApplicationsMatching:registerUpdateToken:]
//   args:   CFDictionaryRef dict
//           CFStringRef token
//   returns CFArrayRef apps
static bool print_applist(am_device_service_connection *conn)
{
    int channel = make_channel(conn, CFSTR("com.apple.instruments.server.services.device.applictionListing"));
    if ( channel < 0 )
        return false;
    
    // the method expects a dictionary and a string argument.
    // pass empty values so we get descriptions for all known applications.
    CFDictionaryRef dict = CFDictionaryCreate(NULL, NULL, NULL, 0, NULL, NULL);
    
    message_aux_t args;
    args.append_obj(dict);
    args.append_obj(CFSTR(""));
    
    CFRelease(dict);
    
    CFTypeRef retobj = NULL;
    
    if ( !send_message(conn, channel, CFSTR("installedApplicationsMatching:registerUpdateToken:"), &args)
        || !recv_message(conn, &retobj, NULL)
        || retobj == NULL )
    {
        fprintf(stderr, "Error: failed to retrieve applist\n");
        return false;
    }
    
    bool ok = true;
    if ( CFGetTypeID(retobj) == CFArrayGetTypeID() )
    {
        CFArrayRef array = (CFArrayRef)retobj;
        for ( size_t i = 0, size = CFArrayGetCount(array); i < size; i++ )
        {
            CFDictionaryRef app_desc = (CFDictionaryRef)CFArrayGetValueAtIndex(array, i);
            printf("%s\n", get_description(app_desc).c_str());
        }
    }
    else
    {
        fprintf(stderr, "apps list has an unexpected format: %s\n", get_description(retobj).c_str());
        ok = false;
    }
    
    CFRelease(retobj);
    return ok;
}

//-----------------------------------------------------------------------------
// invoke method -[DTProcessControlService killPid:]
//   args:    CFNumberRef process_id
//   returns: void
static bool kill(am_device_service_connection *conn, int pid)
{
    int channel = make_channel(conn, CFSTR("com.apple.instruments.server.services.processcontrol"));
    if ( channel < 0 )
        return false;
    
    CFNumberRef _pid = CFNumberCreate(NULL, kCFNumberSInt32Type, &pid);
    
    message_aux_t args;
    args.append_obj(_pid);
    
    CFRelease(_pid);
    
    return send_message(conn, channel, CFSTR("killPid:"), &args, false);
}

//-----------------------------------------------------------------------------
// invoke method -[DTProcessControlService launchSuspendedProcessWithDevicePath:bundleIdentifier:environment:arguments:]
//   args:    CFStringRef app_path
//            CFStringRef bundle_id
//            CFArrayRef args_for_app
//            CFDictionaryRef environment_vars
//            CFDictionaryRef launch_options
//   returns: CFNumberRef pid
static bool launch(am_device_service_connection *conn, const char *_bid)
{
    int channel = make_channel(conn, CFSTR("com.apple.instruments.server.services.processcontrol"));
    if ( channel < 0 )
        return false;
    
    // app path: not used, just pass empty string
    CFStringRef path = CFStringCreateWithCString(NULL, "", kCFStringEncodingUTF8);
    // bundle id
    CFStringRef bid = CFStringCreateWithCString(NULL, _bid, kCFStringEncodingUTF8);
    // args for app: not used, just pass empty array
    CFArrayRef appargs = CFArrayCreate(NULL, NULL, 0, NULL);
    // environment variables: not used, just pass empty dictionary
    CFDictionaryRef env = CFDictionaryCreate(NULL, NULL, NULL, 0, NULL, NULL);
    
    // launch options
    int _v0 = 0; // don't suspend the process after starting it
    int _v1 = 1; // kill the application if it is already running
    
    CFNumberRef v0 = CFNumberCreate(NULL, kCFNumberSInt32Type, &_v0);
    CFNumberRef v1 = CFNumberCreate(NULL, kCFNumberSInt32Type, &_v1);
    
    const void *keys[] =
    {
        CFSTR("StartSuspendedKey"),
        CFSTR("KillExisting")
    };
    const void *values[] = { v0, v1 };
    CFDictionaryRef options = CFDictionaryCreate(
                                                 NULL,
                                                 keys,
                                                 values,
                                                 2,
                                                 NULL,
                                                 NULL);
    
    message_aux_t args;
    args.append_obj(path);
    args.append_obj(bid);
    args.append_obj(env);
    args.append_obj(appargs);
    args.append_obj(options);
    
    CFRelease(v1);
    CFRelease(v0);
    CFRelease(options);
    CFRelease(env);
    CFRelease(appargs);
    CFRelease(bid);
    CFRelease(path);
    
    CFTypeRef retobj = NULL;
    
    if ( !send_message(conn, channel, CFSTR("launchSuspendedProcessWithDevicePath:bundleIdentifier:environment:arguments:options:"), &args)
        || !recv_message(conn, &retobj, NULL)
        || retobj == NULL )
    {
        fprintf(stderr, "Error: failed to launch %s\n", _bid);
        return false;
    }
    
    bool ok = true;
    if ( CFGetTypeID(retobj) == CFNumberGetTypeID() )
    {
        CFNumberRef _pid = (CFNumberRef)retobj;
        int pid = 0;
        CFNumberGetValue(_pid, kCFNumberSInt32Type, &pid);
        printf("pid: %d\n", pid);
    }
    else
    {
        fprintf(stderr, "failed to retrieve the process ID: %s\n", get_description(retobj).c_str());
        ok = false;
    }
    
    CFRelease(retobj);
    return ok;
}

//-----------------------------------------------------------------------------
static void usage(const char *prog)
{
    fprintf(stderr, "usage: %s [-v] [-d <device id>] TASK <task args>\n"
            "\n"
            "This is a sample client application for the iOS Instruments server.\n"
            "It is capable of rudimentary communication with the server and can\n"
            "ask it to perform some interesting tasks.\n"
            "\n"
            "TASK can be one of the following:\n"
            "  proclist  - print a list of running processes\n"
            "  applist   - print a list of installed applications\n"
            "  launch    - launch a given app. provide the bundle id of the app to launch\n"
            "  kill      - kill a given process. provide the pid of the process to kill\n"
            "\n"
            "other args:\n"
            "  -v  more verbose output\n"
            "  -d  device ID. if empty, this app will use the first device it finds\n", prog);
}

//-----------------------------------------------------------------------------
static bool parse_args(int argc, const char **argv)
{
    if ( argc > 1 )
    {
        for ( int i = 1; i < argc; )
        {
            if ( strcmp("-v", argv[i]) == 0 )
            {
                verbose = true;
                i++;
                continue;
            }
            else if ( strcmp("-d", argv[i]) == 0 )
            {
                if ( i == argc - 1 )
                {
                    fprintf(stderr, "Error: -d option requires a device id string\n");
                    break;
                }
                device_id = argv[i+1];
                i += 2;
                continue;
            }
            
            string_t task = argv[i];
            
            if ( task == "proclist" )
            {
                proclist = true;
                return true;
            }
            else if ( task == "applist" )
            {
                applist = true;
                return true;
            }
            else if ( task == "kill" )
            {
                if ( i == argc - 1 )
                {
                    fprintf(stderr, "Error: \"kill\" requires a process id\n");
                    break;
                }
                pid2kill = atoi(argv[i+1]);
                return true;
            }
            else if ( task == "launch" )
            {
                if ( i == argc - 1 )
                {
                    fprintf(stderr, "Error: \"launch\" requires a bundle id\n");
                    break;
                }
                bid2launch = argv[i+1];
                return true;
            }
            
            fprintf(stderr, "Error, invalid task: %s\n", task.c_str());
            break;
        }
    }
    
    usage(argv[0]);
    return false;
}

//-----------------------------------------------------------------------------



int test(int argc, const char **argv)
{
    //  if ( !parse_args(argc, argv) )
    //    return EXIT_FAILURE;
    
    if ( !MobileDevice.load() )
        return EXIT_FAILURE;
    
    am_device_service_connection *conn = start_server();
    if ( conn == NULL )
        return EXIT_FAILURE;
    
    bool ok = false;
    if ( perform_handshake(conn) )
    {
        if ( proclist )
            ok = print_proclist(conn);
        else if ( applist )
            ok = print_applist(conn);
        else if ( pid2kill > 0 )
            ok = kill(conn, pid2kill);
        else if ( bid2launch != NULL )
            ok = launch(conn, bid2launch);
        else
            ok = true;
        
        CFRelease(channels);
    }
    
    MobileDevice.AMDServiceConnectionInvalidate(conn);
    CFRelease(conn);
    
    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}


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
