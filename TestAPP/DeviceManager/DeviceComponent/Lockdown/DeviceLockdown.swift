//
//  DeviceLockDown.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

import Cocoa
import LibMobileDevice


class DeviceLockdown: NSObject {
    // MARK: - Read Only -
    
    private(set) var device: idevice_t? = nil
    
    private(set) var lockdown: lockdownd_client_t? = nil
    
    private(set) var deivceInfo: [String : Any] = [:]
    
    private(set) var udid: String? = nil
    
    // MARK: - Private -
    
    private var serviceDic: [String : lockdownd_service_descriptor_t] = [:]
    
    deinit {
        if let lockdown = lockdown {
            lockdownd_client_free(lockdown)
        }
        
        if let device = device {
            idevice_free(device)
        }
        
        serviceDic.values.forEach { service in
            lockdownd_service_descriptor_free(service)
        }
    }
}

extension DeviceLockdown {
    @discardableResult
    public func setup(_ udid: String, type: DeviceConnectType) -> Self? {
        guard let cudid = udid.cString(using: .utf8),
              let label = "LOCKDOWN".cString(using: .utf8) else {
            return nil
        }
        
        let state = idevice_new_with_options(&device, cudid, type == .usb ? IDEVICE_LOOKUP_USBMUX : IDEVICE_LOOKUP_NETWORK)
        guard state == IDEVICE_E_SUCCESS else {
            return nil
        }
        
        guard lockdownd_client_new_with_handshake(device, &lockdown, label) == LOCKDOWN_E_SUCCESS else {
            return nil
        }
        
        self.udid = udid
        
        return self
    }
}

extension DeviceLockdown: DeviceLockdownServerInterface {
    func server(id: String) -> lockdownd_service_descriptor_t? {
        if let servic = serviceDic[id] {
            return servic
        }
        
        guard let lockdown = lockdown,
              let cid = id.cString(using: .utf8) else {
            return nil
        }
        
        var service: lockdownd_service_descriptor_t? = nil
        
        guard lockdownd_start_service(lockdown, cid, &service) == LOCKDOWN_E_SUCCESS else {
            return nil
        }
        
        if let service = service {
            serviceDic[id] = service
        }
        
        return service
    }
    
    func server(type: DeviceLockdownServerType) -> lockdownd_service_descriptor_t? {
        return server(id: type.id)
    }
}
