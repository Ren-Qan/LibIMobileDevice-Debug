//
//  IIntrumentsProtocols.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/28.
//

import Cocoa

enum IInstrumentsServiceName: String, CaseIterable {
    case sysmontap = "com.apple.instruments.server.services.sysmontap"
        
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
    init()
    
    var server: IInstrumentsServiceName { get }
    
    var instrument: IIntruments? { get }
        
    var expectsReply: Bool { get }
    
    func args(selector: String) -> DTXArguments?
    
    func request(selector: String)
    
    func start()
    
    var startSuccess: Bool { get }
}

extension IInstrumentsServiceProtocol {
    var instrument: IIntruments? {
        if let service = self as? IInstrumentsBaseService {
            return service.instrumentHandle
        }
        return nil
    }
    
    var expectsReply: Bool {
        return true
    }
    
    func request(selector: String) {
        guard startSuccess else {
            return
        }
        
        let args = args(selector: selector)
        let channel = server.channel
        
        instrument?
            .request(channel: channel,
                     selector: selector,
                     args: args,
                     expectsReply: expectsReply)
    }
    
    func response() {
        instrument?.response()
    }
    
    func start() {
        let success = instrument?.setup(service: self) ?? false
        if let service = self as? IInstrumentsBaseService {
            service.isStartSuccess = success
        }
    }
    
    var startSuccess: Bool {
        if let success = (self as? IInstrumentsBaseService)?.isStartSuccess {
            return success
        }
        return false
    }
}
