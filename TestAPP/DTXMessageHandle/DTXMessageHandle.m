//
//  DTXMessageHandle.m
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/21.
//

#import "DTXMessageHandle.h"
#import "DTXArguments.h"

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include <libimobiledevice/lockdown.h>
#include <libimobiledevice/mobile_image_mounter.h>
#include <libimobiledevice/service.h>

#define REMOTESERVER_SERVICE_NAME "com.apple.instruments.remoteserver.DVTSecureSocketProxy"

struct DTXMessageHeader {
    uint32_t magic;
    uint32_t cb;
    uint16_t fragmentId;
    uint16_t fragmentCount;
    uint32_t length;
    uint32_t identifier;
    uint32_t conversationIndex;
    uint32_t channelCode;
    uint32_t expectsReply;
};

struct DTXMessagePayloadHeader {
    uint32_t flags;
    uint32_t auxiliaryLength;
    uint64_t totalLength;
};

@interface DTXMessageHandle()

/// [server_name : channel]
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *channelMap;

/// [channel : server_model]
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DTXServerModel *> *serverMap;

@end

@implementation DTXMessageHandle {
    idevice_connection_t _connection;
    mobile_image_mounter_client_t _mounter_client;
    
    uint32_t _cur_message_tag;
    uint32_t _cur_channel_tag;
    
    NSDictionary *_server_dic;
}

- (void)dealloc {
    [self stopService];
}

//MARK: - Lazy Getter -

- (NSMutableDictionary<NSString *,NSNumber *> *)channelMap {
    if(!_channelMap) {
        _channelMap = [NSMutableDictionary dictionary];
    }
    return _channelMap;
}

- (NSMutableDictionary<NSNumber *,DTXServerModel *> *)serverMap {
    if(!_serverMap) {
        _serverMap = [NSMutableDictionary dictionary];
    }
    return _serverMap;
}

// MARK: - Private -

- (void)makeError:(NSString *)error {
    if ([self.delegate respondsToSelector:@selector(error:handle:)]) {
        [self.delegate error:error handle:self];
    }
}

- (void)xmlWithPlist:(plist_t)plist {
    char *xml = NULL;
    uint32_t len;
    plist_to_xml(plist, &xml, &len);
    NSString *str = [NSString stringWithUTF8String:xml];
    NSLog(@"%@", str);
}

// MARK: - Setup -

- (BOOL)setupWithDevice:(idevice_t)device {
    if (!device) {
        return NO;
    }
    int error = mobile_image_mounter_start_service(device, &_mounter_client, "INSTRUMENTS");
    if (error != 0) {
        [self makeError:@"mounter_start_service_failed"];
        return NO;
    }
    
    plist_t mounter_lookup_result;
    if (mobile_image_mounter_lookup_image(_mounter_client, "Developer", &mounter_lookup_result) != 0) {
        [self makeError:@"mounter_lookup_image_failed"];
        return NO;
    }
    
    plist_t signatureDic = plist_dict_get_item(mounter_lookup_result, "ImageSignature");
    plist_t signatureArr = plist_array_get_item(signatureDic, 0);
    
    [self xmlWithPlist:mounter_lookup_result];
    
    char *signatureString;
    uint64_t signtureLen;
    plist_get_data_val(signatureArr, &signatureString, &signtureLen);
    
    plist_free(signatureDic);
    if (signtureLen <= 0 || signatureString == NULL) {
        [self makeError:@"not found signature"];
        return NO;
    }
    
    // upload image
    if (mobile_image_mounter_upload_image(_mounter_client, "Developer", 9, signatureString, (uint16_t)signtureLen, upload_mounter_callback, NULL) != 0) {
        [self makeError:@"upload image error"];
        return NO;
    }
    
    // get imagePath
    char * image_path = find_image_path(device);
    if (image_path == NULL) {
        [self makeError:@"not found imagePath"];
        return NO;
    }
    
    plist_t result = NULL;
    if (mobile_image_mounter_mount_image(_mounter_client, image_path, signatureString, signtureLen, "Developer", &result) != 0) {
        [self makeError:@"mount image failed"];
        free(image_path);
        return NO;
    }
    
    free(image_path);
        
    // service start
    if (service_client_factory_start_service(device, REMOTESERVER_SERVICE_NAME, (void **)(&_connection), "Remote", SERVICE_CONSTRUCTOR(constructor_remote_service), NULL) != 0) {
        [self makeError:@"strat instruments service failed"];
        return NO;
    }
    
    if (_connection) {
        return [self instrumentsShakeHand];
    }
    
    return NO;
}

- (BOOL)instrumentsShakeHand {
    NSDictionary * par = @{
        @"com.apple.private.DTXBlockCompression" : [NSNumber numberWithLongLong:2],
        @"com.apple.private.DTXConnection" : [NSNumber numberWithLongLong:1]
    };
    
    DTXArguments *args = [[DTXArguments alloc] init];
    [args addObject:par];
    
    [self sendWithChannel:9
                 selector:@"_notifyOfPublishedCapabilities:"
                     args:args
             expectsReply:NO
              serverModel:NULL];
    DTXReceiveObject *result= [self receive];
    
    NSString *string = (NSString *)[result object];
    NSDictionary *serverDic = (NSDictionary *)[result.array firstObject];
    BOOL success = NO;
    
    if (string && serverDic) {
        if ([string isKindOfClass:[NSString class]] && [string isEqualToString:@"_notifyOfPublishedCapabilities:"] && [serverDic isKindOfClass:[NSDictionary class]]) {
            _server_dic = serverDic;
            success = YES;
        }
    }
    
    if (!success) {
        [self makeError:@"instruments hand shake failed"];
    }
    
    return success;
}

- (NSData *)getByteWithObj:(id)obj {
    return [NSKeyedArchiver archivedDataWithRootObject:obj requiringSecureCoding:NO error:NULL];
}

- (uint32_t)nextChannel {
    _cur_channel_tag += 1;
    return _cur_channel_tag;
}

- (void)makechannelWithServer:(NSString *)server {
    if (!_server_dic) {
        return;
    }
    
    if (![_server_dic objectForKey:server]) {
        return;
    }
    
    if ([self.channelMap objectForKey:server]) {
        return;
    }
        
    int code = [self nextChannel];
    DTXArguments *arg = [DTXArguments args];
    [arg appendInt:code];
    [arg appendData:[self getByteWithObj:server]];
    
    self.channelMap[server] = @(code);
    
    [self sendWithChannel:0 selector:@"_requestChannelWithCode:identifier:" args:arg expectsReply:YES serverModel:NULL];
}

// MARK: - Public -

- (void)stopService {
    _connection = NULL;
    _mounter_client = NULL;
    _cur_message_tag = 0;
    _cur_channel_tag = 1;
    _server_dic = NULL;
    _channelMap = NULL;
    _serverMap = NULL;
    
    if (_connection) {
        idevice_disconnect(_connection);
    }
    
    if (_mounter_client) {
        mobile_image_mounter_free(_mounter_client);
    }
}

- (BOOL)connectInstrumentsServiceWithDevice:(idevice_t)device {
    [self stopService];
    return [self setupWithDevice:device];
}

- (void)requestForServer:(NSString *)server
                selector:(NSString *)selector
                    args:(nullable DTXArguments *)args {
    if (!_connection) {
        return;
    }
    
    [self makechannelWithServer:server];
    NSNumber *object = [self.channelMap objectForKey:server];
    if (!object) {
        return;
    }
    uint32_t channel = object.unsignedIntValue;
    
    DTXServerModel *model = self.serverMap[@(channel)];
    if (!model) {
        model = [[DTXServerModel alloc] init];
        model.channel = channel;
        model.server = server;
        self.serverMap[@(channel)] = model;
    } else {
        model.selector = selector;
    }
    
    [self sendWithChannel:channel selector:selector args:args expectsReply:YES serverModel:model];
}

- (void)responseForReceive {
    if (!_connection) {
        return;
    }
    
    DTXReceiveObject *result = [self receive];
    
    uint32_t channel = result.channel;
    
    if (result.flag == 1) {
        channel = UINT32_MAX - result.channel + 1;
    }
    
    DTXServerModel *server = self.serverMap[@(channel)];
    
    if (!server) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(responseServer:object:handle:)]) {
        [self.delegate responseServer:server object:result handle:self];
    }
}

- (BOOL)isServerBuildSuccessWithName:(NSString *)name {
    return self.channelMap[name] != NULL;
}

// MARK: Send Message / Receive Message

- (BOOL)sendWithChannel:(uint32_t)channel
               selector:(NSString *)selector
                   args:(DTXArguments *)args
           expectsReply:(BOOL)expectsReply
            serverModel:(DTXServerModel *)model {
    uint32 identifier = _cur_message_tag;
    _cur_message_tag += 1;
    NSData *selData = [self getByteWithObj:selector];
    NSData *argData = [args getArgBytes];
    
    struct DTXMessagePayloadHeader pheader;
    pheader.flags = 0x2 | (expectsReply ? 0x1000 : 0);
    pheader.auxiliaryLength = (uint32)(argData.length);
    pheader.totalLength = argData.length + selData.length;
    
    struct DTXMessageHeader mheader;
    mheader.magic = 0x1F3D5B79;
    mheader.cb = sizeof(struct DTXMessageHeader);
    mheader.fragmentId = 0;
    mheader.fragmentCount = 1;
    mheader.length = (uint32_t)(sizeof(pheader) + pheader.totalLength);
    mheader.identifier = (uint32_t)identifier;
    mheader.conversationIndex = 0;
    mheader.channelCode = channel;
    mheader.expectsReply = (expectsReply ? 1 : 0);
    
    DTXArguments *argument = [[DTXArguments alloc] init];
    [argument append_v:&mheader len:sizeof(mheader)];
    [argument append_v:&pheader len:sizeof(pheader)];
    [argument append_b:argData];
    [argument append_b:selData];
    
    uint32_t nsent;
    NSData *datas = [argument bytes];
    size_t msglen = datas.length;
    
    if (model) {
        model.identifier = identifier;
    }
    
    
    idevice_connection_send(_connection, [datas bytes], (uint32_t)msglen, &nsent);
    
    return nsent == msglen;
}

- (DTXReceiveObject *)receive {
    uint32_t channelCode = 0;
    uint32_t identifier = 0;
    DTXArguments *payload = [[DTXArguments alloc] init];
    
    while (true) {
        struct DTXMessageHeader mheader;
        uint32_t nrecv = 0;
        idevice_connection_receive(_connection, (char *)(&mheader), sizeof(mheader), &nrecv);
        
        if (nrecv != sizeof(mheader)) {
            fprintf(stderr, "failed to read message header: %s, nrecv = %x\n", strerror(errno), nrecv);
            return NULL;
        }
        
        if ( mheader.magic != 0x1F3D5B79 ) {
            fprintf(stderr, "bad header magic: %x\n", mheader.magic);
            return NULL;
        }
        
        if ( mheader.conversationIndex == 1 ) {
            
        } else if ( mheader.conversationIndex == 0 ) {
            if (mheader.identifier > _cur_message_tag) {
                // new message id, we must update the count on our side
                _cur_message_tag = mheader.identifier;
            }
        } else {
            fprintf(stderr, "invalid conversation index: %d\n", mheader.conversationIndex);
            return NULL;
        }
        
        if ( mheader.fragmentId == 0 ) {
            identifier = mheader.identifier;
            channelCode = mheader.channelCode;
            if ( mheader.fragmentCount > 1 )
                continue;
        }
        
        DTXArguments *frag = [[DTXArguments alloc] init];
        uint32_t nbytes = 0;
        uint8_t *fragData = (uint8_t *)malloc(sizeof(uint8_t) * mheader.length);
        
        while (nbytes < mheader.length) {
            uint8_t *curptr = fragData + nbytes;
            size_t curlen = mheader.length - nbytes;
            idevice_connection_receive(_connection, (char *)curptr, (uint32_t)curlen, &nrecv);
                    
            if ( nrecv <= 0 ) {
                fprintf(stderr, "failed reading from socket: %s\n", strerror(errno));
                return NULL;
            }
            
            NSData *temData = [NSData dataWithBytes:curptr length:nrecv];
            [frag.bytes appendData:temData];
            
            nbytes += nrecv;
        }

        [payload append_v:frag.bytes.bytes len:frag.bytes.length];
        if (mheader.fragmentId == mheader.fragmentCount - 1) {
            break;
        }
    }
    
    struct DTXMessagePayloadHeader *pheader = (struct DTXMessagePayloadHeader *)(payload.bytes.bytes);
    
    uint8_t compression = (pheader->flags & 0xFF000) >> 12;
    if (compression != 0) {
        return NULL;
    }
    
    // serialized object array is located just after payload header
    const uint8_t *auxptr = payload.bytes.bytes + sizeof(struct DTXMessagePayloadHeader);
    uint32_t auxlen = pheader->auxiliaryLength;
    
    // archived payload object appears after the auxiliary array
    const uint8_t *objptr = auxptr + auxlen;
    uint64_t objlen = pheader->totalLength - auxlen;
    
    DTXReceiveObject *result = [[DTXReceiveObject alloc] init];
    
    [result setChannel:channelCode];
    [result setIdentifier:identifier];
    [result setFlag:pheader -> flags];
    
    if (auxlen != 0) {
        NSData *data = [NSData dataWithBytesNoCopy:(void *)auxptr length:auxlen freeWhenDone:NO];
        [result deserializeWithData:data];
    }
    
    if (objlen != 0) {
        NSData *data = [NSData dataWithBytesNoCopy:(void *)objptr length:objlen freeWhenDone:NO];
        [result unarchiverWithData:data];
    }
    return result;
}

// MARK: - C Func -

ssize_t upload_mounter_callback(void* buffer, size_t length, void *user_data) {
    return 0;
}

int32_t constructor_remote_service(idevice_t device,
                                   lockdownd_service_descriptor_t service,
                                   idevice_connection_t * conn) {
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
    
    (*conn) = connection;
    return SERVICE_E_SUCCESS;
}

char * idevice_get_version(idevice_t device) {
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

@end
