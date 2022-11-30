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
    
    lazy var sysmontap = IInstrumentsSysmontap()
    
    lazy var deviceInfo = IInstrumentsDeviceInfo()
        
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = NSButton(title: "app list", target: self, action: #selector(getDeviceList))
        button.frame = .init(origin: .zero, size: .init(width: 200, height: 50))
        view.addSubview(button)
        
        DispatchQueue.global().async {
            MobileManager.share.refreshDeviceList()
        }
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
                self.sysmontap.request()
                self.deviceInfo.request()
                return
            }

            let device = MobileManager.share.deviceList.first { item in
                if item.type == .usb {
                    return true
                }
                return false
            }

            guard let device = device,
                  let iDevice = IDevice(device) else {
                return
            }

            if !instrument.isConnected, instrument.start(iDevice) {
                self.sysmontap.start(instrument)
                self.sysmontap.register(.setConfig)
                self.sysmontap.register(.start)
                                
                self.deviceInfo.start(instrument)
                self.deviceInfo.register(.runningProcesses)
                            
                return
            }
        }
    }
}

