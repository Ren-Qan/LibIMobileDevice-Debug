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
    
    case procList
    
    var id: String {
        switch self {
            case .appList: return "com.apple.mobile.installation_proxy"
            case .procList: return "com.apple.instruments.server.services.deviceinfo"
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
