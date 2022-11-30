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
    private var channel_tag: UInt32 = 0
    
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
    
    func setup(service: any IInstrumentsServiceProtocol) {
        if !isConnected {
            return
        }
        
        if !dtxService.isVaildServer(service.server.rawValue) {
            return
        }
        
        let arg = DTXArguments()
        arg.appendNum32(Int32(service.server.channel))
        arg.add(service.server.rawValue)

        dtxService.send(withChannel: 0,
                        identifier: nextIdentifier,
                        selector: "_requestChannelWithCode:identifier:",
                        args: arg,
                        expectsReply: true)
    }
    
    func request(channel: UInt32,
                 identifier: UInt32,
                 selector: String,
                 args: DTXArguments?,
                 expectsReply: Bool) {
        requestQ.addOperation { [weak self] in
            self?.dtxService.send(withChannel: channel,
                                  identifier: identifier,
                                  selector: selector,
                                  args: args,
                                  expectsReply: expectsReply)
        }
    }
    
    func response(_ complete: ((DTXReceiveObject?) -> Void)? = nil) {
        responseQ.addOperation { [weak self] in
            let result = self?.dtxService.receive()
            complete?(result)
        }
    }
}
