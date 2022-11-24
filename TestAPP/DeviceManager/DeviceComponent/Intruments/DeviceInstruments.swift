//
//  DeviceInstruments.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/21.
//

import Cocoa
import LibMobileDevice

class DeviceInstruments: NSObject {
    private var connection: idevice_connection_t? = nil
    private var mounter_client: mobile_image_mounter_client_t? = nil
    
    deinit {
        if let mounter_client = mounter_client {
            mobile_image_mounter_free(mounter_client)
        }
    }
    
    func setup(_ udid: String, type: DeviceConnectType) -> Self? {
        guard let cudid = udid.cString(using: .utf8) else {
            return nil
        }
        var device: idevice_t? = nil
        idevice_new_with_options(&device, cudid, type == .usb ? IDEVICE_LOOKUP_USBMUX : IDEVICE_LOOKUP_NETWORK)
        
        guard let device = device else {
            return nil
        }
        
        guard mobile_image_mounter_start_service(device, &mounter_client, cudid).rawValue == 0,
              let mounter_client = mounter_client,
              let image_type = "Developer".cString(using: .utf8) else {
            return nil
        }

        var mounter_lookup_result: plist_t? = nil
        guard mobile_image_mounter_lookup_image(mounter_client, image_type, &mounter_lookup_result).rawValue == 0,
              let mounter_lookup_result = mounter_lookup_result else {
            return nil
        }
        
        let signture_string_point = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: 1)
        var len: UInt64 = 0
        
        if let signature_dic = plist_dict_get_item(mounter_lookup_result, "ImageSignature".cString(using: .utf8)!),
           let signature_arr = plist_array_get_item(signature_dic, 0) {
            plist_get_data_val(signature_arr, signture_string_point, &len)
            plist_free(signature_dic)
        }
        
        if len <= 0 {
            signture_string_point.deallocate()
            return nil
        }
        
        
        
        
        return self
    }
}
