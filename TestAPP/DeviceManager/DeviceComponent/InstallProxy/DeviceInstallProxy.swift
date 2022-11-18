//
//  DeviceInstallProxy.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/15.
//

import Cocoa
import LibMobileDevice

enum DeviceAppListType: String {
    case `internal` = "Internal"
    case system = "System"
    case user = "User"
    case any = "Any"

    var key: String {
        return "ApplicationType"
    }
}

struct APPInfo {
    var rawinfo: [String: Any]? = nil

    var name: String? {
        return rawinfo?["CFBundleDisplayName"] as? String
    }

    var bundleID: String? {
        return rawinfo?["CFBundleIdentifier"] as? String
    }

    var isDevelopAPP: Bool {
        guard let signer = rawinfo?["SignerIdentity"] as? String else {
            return false
        }

        return (!signer.hasPrefix("Apple") && signer.contains("Developer")) || (signer.contains("Apple Development"))
    }
}

class DeviceInstallProxy: NSObject {
    private var instproxy: instproxy_client_t?

    deinit {
        if let instproxy = instproxy {
            instproxy_client_free(instproxy)
        }
    }
}

extension DeviceInstallProxy {
    public func setup(_ lockdown: DeviceLockdown) -> Self? {
        guard let _device = lockdown.device,
              let _service = lockdown.server(type: .appList) else {
            return nil
        }

        instproxy_client_new(_device, _service, &instproxy)

        return self
    }

    public func applist(type: DeviceAppListType) -> [APPInfo] {
        guard let ckey = type.key.cString(using: .utf8),
              let cvalue = type.rawValue.cString(using: .utf8),
              let _instprox = instproxy else {
            return []
        }

        var applist: [APPInfo]? = nil
        var result: plist_t? = nil

        let command = plist_new_dict()
        plist_dict_set_item(command, ckey, plist_new_string(cvalue))

        if instproxy_browse(_instprox, command, &result) == INSTPROXY_E_SUCCESS,
           let list = plist_to_nsobject(result) as? NSArray {
            applist = list.compactMap { item in
                if let dic = item as? [String: Any] {
                    return APPInfo(rawinfo: dic)
                }
                return nil
            }
        }

        plist_free(command)
        
        if let result = result {
            plist_free(result)
        }
        
        return applist ?? []
    }
}
