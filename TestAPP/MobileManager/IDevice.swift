//
//  IDevice.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/24.
//

import Cocoa
import LibMobileDevice

enum DeviceConnectType {
    case usb
    case net
    
    var option: idevice_options {
        switch self {
            case .usb:
                return IDEVICE_LOOKUP_USBMUX
            case .net:
                return IDEVICE_LOOKUP_NETWORK
        }
    }
}

struct DeviceItem {
    let udid: String
    let type: DeviceConnectType
    let data: Data?
}

class IDevice: NSObject {
    public private(set) var device_t: idevice_t? = nil
    public private(set) var deviceItem: DeviceItem? = nil

    convenience init?(_ udid: String, _ type: DeviceConnectType) {
        self.init(.init(udid: udid, type: type, data: nil))
    }
    
    convenience init?(_ item: DeviceItem) {
        var _device: idevice_t? = nil
        idevice_new_with_options(&_device, item.udid, item.type.option)
        
        if let _device = _device {
            self.init()
            self.device_t = _device
            self.deviceItem = item
        } else {
            return nil
        }
    }
    
    deinit {
        if let device = device_t {
            idevice_free(device)
        }
    }
}

// MARK: - Public -
extension IDevice {
    func reset(_ udid: String, _ type: DeviceConnectType) {
        reset(.init(udid: udid, type: type, data: nil))
    }
    
    func reset(_ item: DeviceItem) {
        if let device = self.device_t {
            idevice_free(device)
        }
        
        self.deviceItem = nil
        self.device_t = nil
        
        var _device: idevice_t? = nil
        idevice_new_with_options(&_device, item.udid, item.type.option)
        
        if let _device = _device {
            self.device_t = _device
            self.deviceItem = item
        }
    }
}
