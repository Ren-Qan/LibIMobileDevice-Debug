//
//  IIntruments.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/24.
//

import Cocoa
import LibMobileDevice

class IIntruments: NSObject {
    private lazy var dtxService: DTXMessageHandle = {
        let server = DTXMessageHandle()
        server.delegate = self
        return server
    }()
    
    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private lazy var resolver = IIntrumentsResolver()
    
    private var timer: Timer? = nil
    
    public private(set) var isConnected = false
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Private -
private extension IIntruments {
    func request(_ server: String, _ selector: String, _ args: DTXArguments?) {
        queue.addOperation { [weak self] in
            self?.dtxService.request(forServer: server, selector: selector, args: args)
        }
    }
}

extension IIntruments {
    func stop() {
        queue.addOperation { [weak self] in
            self?.isConnected = false
            self?.dtxService.stopService()
        }
    }
    
    func start(_ device: IDevice) {
        guard let device_t = device.device_t else {
            return
        }
        
        isConnected = dtxService.connectInstrumentsService(withDevice: device_t)
    }
    
    func response() {
        queue.addOperation { [weak self] in
            self?.dtxService.responseForReceive()
        }
    }
    
    func refreshAppProcessList() {
        let server = "com.apple.instruments.server.services.deviceinfo"
        let selector = "runningProcesses"
        request(server, selector, nil)
    }
    
    func cpu() {
        
    }
    
    func gpu() {
        
    }
}

extension IIntruments: DTXMessageHandleDelegate {
    func receive(withServer server: String, object: DTXReceiveObject, handle: DTXMessageHandle) {
        
    }
    
    func error(_ error: String, handle: DTXMessageHandle) {
        
    }
}
