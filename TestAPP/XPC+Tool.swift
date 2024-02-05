//
//  XPC+Tool.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/5.
//

import AppKit

extension XPC.Wrapper {
    class Maker {
        fileprivate var object: XPCObjectProtocol!
        fileprivate var messageID: UInt64!
        fileprivate var flags: XPC.Flags!
        
        @discardableResult
        public func object(_ value: XPCObjectProtocol) -> Self {
            self.object = value
            return self
        }
        
        @discardableResult
        public func message(_ id: UInt64) -> Self {
            self.messageID = id
            return self
        }
        
        @discardableResult
        public func flags(_ value: XPC.Flags) -> Self {
            self.flags = value
            return self
        }
    }
    
    static func creat(_ make: (Maker) -> Void) -> XPC.Wrapper {
        let maker = Maker()
        make(maker)
        let payload = XPC.Payload(maker.object)
        let message = XPC.Message(maker.messageID, payload)
        let wrapper = XPC.Wrapper(maker.flags, message)
        return wrapper
    }
    
    static func data(_ make: (Maker) -> Void) -> Data {
        creat(make).bytes()
    }
}
