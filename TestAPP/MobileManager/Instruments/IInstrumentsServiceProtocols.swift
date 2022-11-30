//
//  IIntrumentsProtocols.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/28.
//

import Cocoa

protocol IInstrumentRequestArgsProtocol {
    var selector: String { get }
    
    var args: DTXArguments? { get }
}

enum IInstrumentsServiceName: String, CaseIterable {
    case sysmontap = "com.apple.instruments.server.services.sysmontap"
    
    case deviceinfo = "com.apple.instruments.server.services.deviceinfo"
        
    var channel: UInt32 {
        return UInt32(IInstrumentsServiceName.allCases.firstIndex(of: self)! + 10)
    }
    
    init?(channel: UInt32) {
        let name = IInstrumentsServiceName.allCases.first { name in
            return name.channel == channel
        }
        if let name = name {
            self = name
        }
        return nil
    }
}

protocol IInstrumentsServiceProtocol: NSObjectProtocol {
    associatedtype Arg : IInstrumentRequestArgsProtocol
    
    var server: IInstrumentsServiceName { get }
        
    func response(_ response: DTXReceiveObject?)
    
    // MARK: - optional -
    
    var instrument: IIntruments? { get }
    
    var identifier: UInt32 { get }
    
    var expectsReply: Bool { get }
    
    func start(_ handle: IIntruments?)
    
    func register(_ arg: Arg)
    
    func request()    
}

extension IInstrumentsServiceProtocol {
    var instrument: IIntruments? {
        if let service = self as? IInstrumentsBaseService {
            return service.instrumentHandle
        }
        return nil
    }
    
    var identifier: UInt32 {
        guard let service = self as? IInstrumentsBaseService else {
            return 0
        }
        return service.nextIdentifier
    }
    
    var expectsReply: Bool {
        return true
    }
    
    func start(_ handle: IIntruments? = nil) {
        if let handle = handle,
           let service = self as? IInstrumentsBaseService {
            service.instrumentHandle = handle
        }
        instrument?.setup(service: self)
    }
    
    func register(_ arg: Arg) {
        let args = arg.args
        let channel = server.channel
        
        instrument?
            .request(channel: channel,
                     identifier: identifier,
                     selector: arg.selector,
                     args: args,
                     expectsReply: expectsReply)
    }
    
    func request() {
        instrument?.response { [weak self] response in
            self?.response(response)
        }
    }
}
