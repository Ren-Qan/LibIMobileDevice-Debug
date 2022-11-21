//
//  DeviceLockdownServerInterface.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/15.
//

import Cocoa
import LibMobileDevice

enum DeviceLockdownServerType: String {
    case appList
        
    var id: String {
        switch self {
            case .appList: return "com.apple.mobile.installation_proxy"
        }
    }
}

protocol DeviceLockdownServerInterface: NSObjectProtocol {
    func server(id: String) -> lockdownd_service_descriptor_t?
    
    func server(type: DeviceLockdownServerType) -> lockdownd_service_descriptor_t?
}

protocol DeviceAPI: NSObjectProtocol {
    func setup<T: DeviceAPI>(_ lockdown: DeviceLockdown) -> T
}
