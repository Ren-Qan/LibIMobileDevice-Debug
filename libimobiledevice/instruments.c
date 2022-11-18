#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>
#include <unistd.h>
#include <plist/plist.h>

#include "installation_proxy.h"
#include "property_list_service.h"
#include "mobile_image_mounter.h"
#include "common/debug.h"

#include "instruments.h"


int instruments_client_new(idevice_t device, mobile_image_mounter_client_t *client, const char* label) {
    
//    mobile_image_mounter_start_service(device, client, label);
//    
//    static plist_t mounter_lookup_result;
//    
//    mobile_image_mounter_lookup_image(client, "Developer", &mounter_lookup_result);
//    mobile_image_mounter_upload_image(<#mobile_image_mounter_client_t client#>, <#const char *image_type#>, <#size_t image_size#>, <#const char *signature#>, <#uint16_t signature_size#>, <#mobile_image_mounter_upload_cb_t upload_cb#>, <#void *userdata#>)
//    mobile_image_mounter_mount_image(<#mobile_image_mounter_client_t client#>, <#const char *image_path#>, <#const char *signature#>, <#uint16_t signature_size#>, <#const char *image_type#>, <#plist_t *result#>)
//    
//    mobile_image_mounter_hangup(<#mobile_image_mounter_client_t client#>)
//    
//    service_client_factory_start_service(<#idevice_t device#>, <#const char *service_name#>, <#void **client#>, <#const char *label#>, <#int32_t (*constructor_func)(idevice_t, lockdownd_service_descriptor_t, void **)#>, <#int32_t *error_code#>)
    
    return 0;
}
