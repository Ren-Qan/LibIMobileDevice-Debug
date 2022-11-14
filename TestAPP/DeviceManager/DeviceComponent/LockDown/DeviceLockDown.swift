//
//  DeviceLockDown.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

import Cocoa
import LibMobileDevice

class DeviceLockDown: NSObject {
    private(set) var device: idevice_t? = nil
    
    private(set) var lockdown: lockdownd_client_t? = nil
    
    private(set) var deivceInfo: [String : Any] = [:]
    
    private(set) var udid: String? = nil
    
    deinit {
        if let lockdown = lockdown {
            lockdownd_client_free(lockdown)
        }
        
        if let device = device {
            idevice_free(device)
        }
    }
}

extension DeviceLockDown {
    @discardableResult
    public func setup(_ udid: String) -> Bool {
        guard let cudid = udid.cString(using: .utf8),
              let label = "LOCKDOWN".cString(using: .utf8) else {
            return false
        }
         
        guard idevice_new(&device, cudid) == IDEVICE_E_SUCCESS else {
            return false
        }
        
        guard lockdownd_client_new_with_handshake(device, &lockdown, label) == LOCKDOWN_E_SUCCESS else {
            return false
        }
        
        self.udid = udid
        
        return true
    }
}

extension DeviceLockDown {
    private func fetchDeviceInfo() {
        
    }
}
