//
//  Bonjour.swift
//  TestAPP
//
//  Created by 任玉乾 on 2023/12/15.
//

import Cocoa

class Bonjour: NSObject {
    private lazy var browser: NetServiceBrowser = {
        let browser = NetServiceBrowser()
        browser.delegate = self
        return browser
    }()
    
    fileprivate var services: [NetService] = []
    
    fileprivate var closure: ((Service) -> Void)? = nil
    fileprivate var isInSearch = false
    
    func search(_ complete: @escaping (Service) -> Void) {
        self.closure = complete
        
        if isInSearch { return }
        
        browser.schedule(in: .main, forMode: .common)
        browser.searchForServices(ofType: "_remoted._tcp.", inDomain: "local.")
    }
}

extension Bonjour: NetServiceBrowserDelegate, NetServiceDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 20)
        browser.stop()
    }
    
    // MARK: - NetServiceDelegate
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let address = sender.addresses {
            closure?(Service(address: address))
            closure = nil
            isInSearch = false
        }
        
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        isInSearch = false
        // Handle error
    }
}

extension Bonjour {
    struct Service {
        let address: [Data]
    }
}
