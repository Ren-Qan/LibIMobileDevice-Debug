//
//  Bonjour.swift
//  TestAPP
//
//  Created by 任玉乾 on 2023/12/15.
//

import Cocoa
import Network

class Bonjour: NSObject {
    private lazy var browser: NetServiceBrowser = {
        let browser = NetServiceBrowser()
        browser.delegate = self
        return browser
    }()
        
    fileprivate var service: NetService? = nil
    fileprivate var search: ((NetService) -> Void)? = nil
    fileprivate var isInSearch = false
    
    func search(_ complete: @escaping (NetService) -> Void) {
        self.search = complete
        if isInSearch { return }
        isInSearch = true
        
        browser.stop()
        browser.schedule(in: .main, forMode: .common)
        let type = "_rdlink._tcp."
//        let type = "_remoted._tcp."
        browser.searchForServices(ofType: type, inDomain: "local.")
    }
}

extension Bonjour: NetServiceBrowserDelegate  {
    func netServiceBrowser(_ browser: NetServiceBrowser, 
                           didFind service: NetService,
                           moreComing: Bool) {
        browser.stop()
        self.service?.stop()
        self.service = service
        self.service?.delegate = self
        self.service?.resolve(withTimeout: 20)
    }
}

extension Bonjour: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        self.search?(sender)
        print(sender)
        self.search = nil
        self.isInSearch = false
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        self.search = nil
        self.isInSearch = false
    }
}
