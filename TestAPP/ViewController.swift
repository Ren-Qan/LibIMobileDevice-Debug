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
    
    lazy var bonjour = Bonjour()
        
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
            self.bonjour.search { service in
                
            }
        }
        
        
    }
}

