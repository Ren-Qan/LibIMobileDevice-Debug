//
//  XPC.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/4.
//

import AppKit

struct XPC { }
extension XPC {
    class Wrapper {
        
    }
}

protocol XPCPayloadProtocol {
    var type: XPC.MessageType { get }
    var data: Any { get }
    func mapping() -> [String : Any]
}
extension XPCPayloadProtocol {
    func mapping() -> [String : Any] {
        return [
            "type" : type,
            "data" : data,
        ]
    }
}

extension XPC {
    struct _Bool: XPCPayloadProtocol {
        var type: MessageType = .bool
        var data: Any
        
        init(_ data: Bool) {
            self.data = data
        }
    }
    
    struct _String: XPCPayloadProtocol {
        var type: MessageType = .string
        var data: Any
        
        init(_ data: String) {
            self.data = data
        }
    }
    
    struct _Array: XPCPayloadProtocol {
        var type: MessageType = .array
        var data: Any
        
        init(_ data: [Any]) {
            self.data = data
        }
    }
    
    struct _Dictionary: XPCPayloadProtocol {
        var type: MessageType = .dictionary
        var data: Any
        
        init(_ data: [String : Any]) {
            self.data = data
        }
    }
    
    struct _Double: XPCPayloadProtocol {
        var type: MessageType = .double
        var data: Any
        
        init(_ data: Double) {
            self.data = data
        }
    }
    
    struct _UUID: XPCPayloadProtocol {
        var type: MessageType = .uuid
        var data: Any
        
        init(_ data: UUID) {
            self.data = data
        }
    }
    
    struct _NULL: XPCPayloadProtocol {
        var type: MessageType = .null
        var data: Any
        
        init() {
            self.data = 0
        }
        
        func mapping() -> [String : Any] {
            return [
                "type" : type,
                "data": Optional<Any>.none as Any
            ]
        }
    }
    
    struct _UInt64: XPCPayloadProtocol {
        var type: MessageType = .uint64
        var data: Any
        
        init(_ data: UInt64) {
            self.data = data
        }
    }
    
    struct _Int64: XPCPayloadProtocol {
        var type: MessageType = .int64
        var data: Any
        
        init(_ data: Int64) {
            self.data = data
        }
    }
    
    struct _Data: XPCPayloadProtocol {
        var type: MessageType = .int64
        var data: Any
        
        init(_ data: Data) {
            self.data = data
        }
    }
}

extension XPC {
    enum MessageType: Int {
        case null = 0x00001000
        case bool = 0x00002000
        case int64 = 0x00003000
        case uint64 = 0x00004000
        case double = 0x00005000
        case pointer = 0x00006000
        case date = 0x00007000
        case data = 0x00008000
        case string = 0x00009000
        case uuid = 0x0000a000
        case fd = 0x0000b000
        case shmem = 0x0000c000
        case machSend = 0x0000d000
        case array = 0x0000e000
        case dictionary = 0x0000f000
        case error = 0x00010000
        case connection = 0x00011000
        case endpoint = 0x00012000
        case serializer = 0x00013000
        case pipe = 0x00014000
        case machRecv = 0x00015000
        case bundle = 0x00016000
        case service = 0x00017000
        case serviceInstance = 0x00018000
        case activity = 0x00019000
        case fileTransfer = 0x0001a000
    }

    enum Flags: Int {
        case alwaysSet = 0x00000001
        case ping = 0x00000002
        case dataPresent = 0x00000100
        case wantingReply = 0x00010000
        case reply = 0x00020000
        case fileTxStreamRequest = 0x00100000
        case fileTxStreamResponse = 0x00200000
        case initHandshake = 0x00400000
    }
}
