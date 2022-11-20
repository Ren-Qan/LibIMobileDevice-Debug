//
//  Instruments.cpp
//  libimobiledevice
//
//  Created by 任玉乾 on 2022/11/19.
//

#include "DTXInstruments.hh"

#include <libimobiledevice/lockdown.h>
#include <libimobiledevice/mobile_image_mounter.h>
#include <libimobiledevice/service.h>

#define REMOTESERVER_SERVICE_NAME "com.apple.instruments.remoteserver.DVTSecureSocketProxy"

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

char * idevice_get_version(idevice_t _Nullable device) {
    if (device == NULL) {
        return NULL;
    }
    
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

instruments_error instruments_start_connection(idevice_t device, idevice_connection_t *conn) {
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
    
    mobile_image_mounter_free(client);
    return 0;
}

void instrument_connection_free(idevice_connection_t conn) {
    if (conn == NULL) {
        return;
    }
    idevice_disconnect(conn);
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
