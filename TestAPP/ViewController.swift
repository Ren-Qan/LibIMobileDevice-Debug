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
    
    lazy var cpu = IInstrumentsCPU()
    
    var processList: [AppProcessItem]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = NSButton(title: "app list", target: self, action: #selector(getDeviceList))
        button.frame = .init(origin: .zero, size: .init(width: 200, height: 50))
        view.addSubview(button)

//        instrument.creatService() as? IInstrumentsCPU
        
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
//        print(IInstrumentsServiceName.aw.channel)
        
        DispatchQueue.global().async {
            action()
            self.cpu.response()
        }
        
        func action() {
            if instrument.isConnected {
                self.cpu.response()
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
                cpu.instrumentHandle = instrument
                self.cpu.start()
                self.cpu.request(arg: IInstrumentCPUArgs.setConfig)
                self.cpu.request(arg: IInstrumentCPUArgs.start)
                return
            }
        }
    }
}

