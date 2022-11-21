//
//  ViewController.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

import Cocoa
// import

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = NSButton(title: "app list", target: self, action: #selector(getDeviceList))
        button.frame = .init(origin: .zero, size: .init(width: 200, height: 50))
        view.addSubview(button)

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    @objc func getDeviceList() {
        DeviceManager.share.refreshDevices()
        let device = DeviceManager.share.deviceList.first { item in
            item.type == .net
        }
    }
}
