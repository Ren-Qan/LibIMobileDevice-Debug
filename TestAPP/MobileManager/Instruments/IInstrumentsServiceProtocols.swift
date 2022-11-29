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
    var server: IInstrumentsServiceName { get }
        
    func response(_ response: DTXReceiveObject?)
    
    // MARK: - optional -
    
    var instrument: IIntruments? { get }
    
    var identifier: UInt32 { get }
    
    var expectsReply: Bool { get }
    
    func start()
    
    func request(arg: IInstrumentRequestArgsProtocol)
    
    func response()
    
    func makeChannel(state: Bool)
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
        return service.next_identifier
    }
    
    var expectsReply: Bool {
        return true
    }
    
    func start() {
        instrument?.setup(service: self)
    }
    
    func request(arg: IInstrumentRequestArgsProtocol) {
        let args = arg.args
        let channel = server.channel
        
        instrument?
            .request(channel: channel,
                     identifier: identifier,
                     selector: arg.selector,
                     args: args,
                     expectsReply: expectsReply)
    }
    
    func response() {
        instrument?.response { [weak self] response in
            if let response = response,
               response.channel == 0 {
                if response.object == nil,
                   response.array == nil {
                    self?.makeChannel(state: true)
                } else {
                    self?.makeChannel(state: false)
                }
            }
            
            self?.response(response)
        }
    }
    
    func makeChannel(state: Bool) {
        
    }
}
