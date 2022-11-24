//
//  DeviceManager.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

import Cocoa
import LibMobileDevice

class DeviceManager: NSObject {
    public private(set) var deviceList = [DeviceItem]()

    static var share: DeviceManager = {
        let device = DeviceManager()
        device.subscribe()
        return device
    }()

    private func subscribe() {
        idevice_event_subscribe({ event, _ in
            if let event = event?.pointee,
               let udid = StringLiteralType(utf8String: event.udid)
            {
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

    func refreshDevices() {
        var devices = [DeviceItem]()

        let listPoint = UnsafeMutablePointer<UnsafeMutablePointer<idevice_info_t?>?>.allocate(capacity: 1)
        let count = UnsafeMutablePointer<Int32>.allocate(capacity: 1)

        idevice_get_device_list_extended(listPoint, count)

        let len = Int(count.pointee)
        let list = listPoint.pointee

        (0 ..< len).forEach { i in
            if let device = list?[i]?.pointee,
               let udid = StringLiteralType(utf8String: device.udid)
            {
                let item = DeviceItem(udid: udid, type: device.conn_type == CONNECTION_USBMUXD ? .usb : .net)
                devices.append(item)
            }
        }

        if let list = list {
            idevice_device_list_extended_free(list)
        }

        deviceList = devices

        listPoint.deallocate()
        count.deallocate()
    }
}

extension DeviceManager {
    func applist(udid: String, type: DeviceConnectType = .usb) -> [APPInfo] {
        guard let lockdown = DeviceLockdown().setup(udid, type: type),
              let installProxy = DeviceInstallProxy().setup(lockdown)
        else {
            return []
        }

        return installProxy.applist(type: .any)
    }
}
