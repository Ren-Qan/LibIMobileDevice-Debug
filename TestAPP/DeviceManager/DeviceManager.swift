//
//  DeviceManager.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

import Cocoa
import LibMobileDevice

class DeviceManager: NSObject {
    static var share: DeviceManager = {
        let device = DeviceManager()
        device.subscribe()
        return device
    }()
    
    private func subscribe() {
        idevice_event_subscribe({ event, _ in
            if let event = event?.pointee,
                let udid = StringLiteralType(utf8String: event.udid) {
                if event.event == IDEVICE_DEVICE_ADD {
                    print("[CONNECT]")
                } else if event.event == IDEVICE_DEVICE_REMOVE {
                    print("[NO CONNECT]")
                }
                print("[UDID] - [\(udid)]")
                print("[TYPE] - [\(event.conn_type == CONNECTION_USBMUXD ? "USB" : "NET")]")
            }
        }, nil)
    }
}
