//
//  IIntruments.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/24.
//

import Cocoa
import LibMobileDevice

class IIntruments: NSObject {
    // MARK: - Private -
    private lazy var dtxService: DTXMessageHandle = {
        let server = DTXMessageHandle()
        return server
    }()
    
    private lazy var requestQ: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private lazy var responseQ: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
            
    private var identifier: UInt32 = 0
    
    // MARK: - Public Getter -
    public private(set) var isConnected = false
}

// MARK: - Private -

private extension IIntruments {
    var nextIdentifier: UInt32 {
        identifier += 1
        return identifier
    }
}

extension IIntruments {
    func stop() {
        isConnected = false
        dtxService.stopService()
    }
    
    @discardableResult
    func start(_ device: IDevice) -> Bool {
        guard let device_t = device.device_t else {
            return false
        }
        
        isConnected = dtxService.connectInstrumentsService(withDevice: device_t)
        return isConnected
    }
    
    func setup(service: IInstrumentsServiceProtocol) -> Bool {
        if !isConnected {
            return false
        }
        
        if !dtxService.isVaildServer(service.server.rawValue) {
            return false
        }
        
        let arg = DTXArguments()
        arg.appendNum32(Int32(service.server.channel))
        arg.append_d(service.server.channel)
        arg.add(service.server.rawValue)

        
        dtxService.send(withChannel: 0,
                        identifier: nextIdentifier,
                        selector: "_requestChannelWithCode:identifier:",
                        args: arg,
                        expectsReply: true)
        let result = dtxService.receive()
        if let result = result, result.object == nil, result.array == nil {
            return true
        }
        
        return false
    }
    
    func request(channel: UInt32, selector: String, args: DTXArguments?, expectsReply: Bool) {
        requestQ.addOperation { [weak self] in
            if let identifier = self?.nextIdentifier {
                self?.dtxService.send(withChannel: channel, identifier: identifier, selector: selector, args: args, expectsReply: expectsReply)
            }
        }
    }
    
    func response() {
        responseQ.addOperation { [weak self] in
            let result = self?.dtxService.receive()
            if let reuslt = result {
                print(result)
            }
            
        }
    }
}
