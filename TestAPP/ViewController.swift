//
//  ViewController.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/14.
//

import Cocoa
import LibMobileDevice
import XPC

class ViewController: NSViewController {
    
    lazy var instrument = IIntruments()
    
    lazy var sysmontap = IInstrumentsSysmontap()
    
    lazy var deviceInfo = IInstrumentsDeviceInfo()
            
    lazy var rsd = RSDService()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = NSButton(title: "app list", target: self, action: #selector(getDeviceList))
        button.frame = .init(origin: .zero, size: .init(width: 200, height: 50))
        view.addSubview(button)
        
        DispatchQueue.global().async {
            MobileManager.share.refreshDeviceList()
            MobileManager.share.deviceList.forEach { item in
                
            }
        }
    }


    @objc func getDeviceList() {
        DispatchQueue.global().async {
            self.getInterfaces()
        }
    }
    
    func getInterfaces() -> [String] {
        var address : UnsafeMutablePointer<ifaddrs>?
        var interfaces = [sockaddr]()

        if getifaddrs(&address) == 0 {
            var ptr = address
            while ptr != nil {
                if let info = ptr?.pointee {
                    let name = String(cString: info.ifa_name)
                    let sock = info.ifa_addr.pointee
                    var v = ""
                    if sock.sa_family == AF_INET6 {
                        v = "V6"
                    } else if sock.sa_family == AF_INET {
                        v = "V4"
                    }
                    if v == "V6" {
                        let sin6 = UnsafeMutablePointer<sockaddr_in6>(OpaquePointer(info.ifa_addr)).pointee

                        var addr = sin6.sin6_addr
                        let ip = withUnsafePointer(to: &addr) { pointer in
                            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                            return String(cString: inet_ntop(Int32(AF_INET6), pointer , &buffer, socklen_t(INET6_ADDRSTRLEN)))
                        }
                        
                        let port = UInt16(bigEndian: sin6.sin6_port)
                        
                        print("IP: \(ip) Port: \(port)")
                    }
                    
                }
                ptr = ptr?.pointee.ifa_next
            }
            freeifaddrs(address)
        }
        return []
    }
}

