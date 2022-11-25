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
    
    var processList: [AppProcessItem]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = NSButton(title: "app list", target: self, action: #selector(getDeviceList))
        button.frame = .init(origin: .zero, size: .init(width: 200, height: 50))
        view.addSubview(button)

        DispatchQueue.global().async {
            MobileManager.share.refreshDeviceList()
        }
        
        instrument.delegate = self
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
                instrument.refreshAppProcessList()
                instrument.cpu()
                instrument.autoReponse(0.5)
                return
            }
        }
    }
}

extension ViewController: IIntrumentsDelegate {
    func appProcess(list: [AppProcessItem]) {
        processList = list
    }
    
    func cpu(info: [[String : Any]]) {
        print("\n\n==============")
        print(info)
        print("============\n\n")
    }
}
