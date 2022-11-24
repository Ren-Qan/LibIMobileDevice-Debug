//
//  ViewController.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

import Cocoa
import LibMobileDevice

class ViewController: NSViewController {
    
    lazy var instrument = IIntruments()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = NSButton(title: "app list", target: self, action: #selector(getDeviceList))
        button.frame = .init(origin: .zero, size: .init(width: 200, height: 50))
        view.addSubview(button)

        DispatchQueue.global().async {
            MobileManager.share.refreshDeviceList()
        }
        
        
        
//        DeviceManager.share.refreshDevices()
//        let device = DeviceManager.share.deviceList.first { item in
//            item.type == .net
//        }
//        var _device: idevice_t? = nil
//        idevice_new_with_options(&_device, device?.udid.cString(using: .utf8)!, IDEVICE_LOOKUP_USBMUX);
//        if (ins == nil) {
//
//            let config: [String : Any] = [
//                "bm": 0,
//                "cpuUsage": true,
//                "ur": 1000,
//                "sampleInterval": 1000000000,
//                "procAttrs": [
//                    "memVirtualSize", "cpuUsage", "ctxSwitch", "intWakeups", "physFootprint", "memResidentSize", "memAnon", "pid"
//                ],
//                "sysAttrs": [
//                    "vmExtPageCount", "vmFreeCount", "vmPurgeableCount", "vmSpeculativeCount", "physMemSize"
//                ]
//            ]
//            let args = DTXArguments()
//            args.add(config)
//
//            let ins = DTXMessageHandle()
//            ins.delegate = self
//            ins.connectInstrumentsService(withDevice: _device!)
//            ins.response(forServer: "com.apple.instruments.server.services.sysmontap", selector: "setConfig:", args: args)
//            ins.response(forServer: "com.apple.instruments.server.services.sysmontap", selector: "start", args: nil)
//
//            self.ins = ins
//        }
//
//        ins?.requestForReceive()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    @objc func getDeviceList() {
        DispatchQueue.global().async {
            action()
        }
        
        func action() {
            if instrument.isConnected {
                instrument.response()
                return
            }
            
            let device = MobileManager.share.deviceList.first { item in
                if item.type == .net {
                    return true
                }
                return false
            }
            
            guard let device = device,
                  let iDevice = IDevice(device) else {
                return
            }
            
            if !instrument.isConnected {
                instrument.start(iDevice)
                instrument.refreshAppProcessList()
                return
            }
        }
    }
}
