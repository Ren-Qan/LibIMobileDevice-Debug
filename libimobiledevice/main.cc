//
//  main.c
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/11.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libimobiledevice.h"
#include "installation_proxy.h"
#include "mobile_image_mounter.h"
#include "service.h"

#include "ios_instruments_client.h"

#define REMOTESERVER_SERVICE_NAME "com.apple.instruments.remoteserver.DVTSecureSocketProxy"

static uint8_t instrument_sslEnable = 0;
static uint16_t instrument_port = 0;


void capabilitie(idevice_connection_t connection) {
    plist_t arg = plist_new_dict();
    plist_dict_set_item(arg, "com.apple.private.DTXBlockCompression", plist_new_uint(2));
    plist_dict_set_item(arg, "com.apple.private.DTXConnection", plist_new_uint(1));
    
    
    plist_t command = plist_new_dict();
    plist_dict_set_item(command, "_notifyOfPublishedCapabilities:", arg);
    
    test(connection);
    print_proclist(connection);
}

static int32_t constructorRemote(idevice_t device, lockdownd_service_descriptor_t service, service_client_t *client) {
    instrument_port = service -> port;
    instrument_sslEnable = service -> ssl_enabled;
    
    // connect
    idevice_connection_t connection;
    idevice_connect(device, instrument_port, &connection);
    
    int fd;
    idevice_connection_get_fd(connection, &fd);
    idevice_connection_enable_ssl(connection);
    
    capabilitie(connection);
    
    return 0;
}

static ssize_t mounter_call_back(void* buffer, size_t length, void *user_data) {
    return 1;
}

char * getVersion(idevice_t device) {
    lockdownd_client_t client_loc = NULL;
    lockdownd_client_new(device, &client_loc, "getVersion");
    
    plist_t p_version = NULL;
    if (lockdownd_get_value(client_loc, NULL, "ProductVersion", &p_version) == LOCKDOWN_E_SUCCESS) {
        char *s_version = NULL;
        plist_get_string_val(p_version, &s_version);
        return s_version;
    }
    
    lockdownd_client_free(client_loc);
    plist_free(p_version);
    return NULL;
}

char * findImagePath(idevice_t device) {
    char * version = getVersion(device);
    if (version == NULL) {
        return NULL;
    }
    
    char * path = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/";
    char * fileName = "/DeveloperDiskImage.dmg";
    
    int len = (int)(strlen(version) + strlen(path) + strlen(fileName) + 1);
    char * result = (char *)malloc(sizeof(char) * len);
    
    strcat(result, path);
    strcat(result, version);
    strcat(result, fileName);

    return result;
}

void xml(plist_t plist) {
    char * xml;
    uint32_t len;
    plist_to_xml(plist, &xml, &len);
    printf("[xml] - %s\n", xml);
    free(xml);
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
    
    
    // start mounter service
    mobile_image_mounter_client_t client;
    mobile_image_mounter_start_service(device, &client, "IN_STRUMENTS");
    
    // look up mounter image signature
    plist_t mounter_lookup_result;
    mobile_image_mounter_lookup_image(client, "Developer", &mounter_lookup_result);
    
    // get signatureString form plist
    plist_t signatureDic = plist_dict_get_item(mounter_lookup_result, "ImageSignature");
    plist_t signatureArr = plist_array_get_item(signatureDic, 0);
    
    char *signatureString;
    uint64_t signtureLen;
    plist_get_data_val(signatureArr, &signatureString, &signtureLen);
    
    // upload image
    mobile_image_mounter_upload_image(client, "Developer", 9, signatureString, (uint16_t)signtureLen, mounter_call_back, NULL);
    
    
    // get imagePath
    char * image_path = findImagePath(device);

    // mount image
    plist_t mountReuslt;
    mobile_image_mounter_mount_image(client, image_path, signatureString, signtureLen, "Developer", &mountReuslt);
 
    
    // service start
    void * remoteClient;
    int32_t reomoteError = 0;
    int error = service_client_factory_start_service(device, REMOTESERVER_SERVICE_NAME, &remoteClient, "ReMote", SERVICE_CONSTRUCTOR(constructorRemote), &reomoteError);
    
    while (1) {
        
    }
    return 0;
}


