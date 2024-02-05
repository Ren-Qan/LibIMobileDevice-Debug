//
//  XPC+Structure.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/5.
//

import AppKit

extension XPC {
    struct Wrapper: XPCByteProtocol {
        let magic: UInt32 = 0x29b00b92
        let flags: XPC.Flags
        let message: XPC.Message
        
        init(_ flags: XPC.Flags, _ message: XPC.Message) {
            self.flags = flags
            self.message = message
        }
        
        func bytes() -> Data {
            var data = Data()
            data.append(withUnsafeBytes(of: magic) { Data($0) })
            data.append(withUnsafeBytes(of: flags.rawValue) { Data($0) })
            data.append(message.bytes())
            return data
        }
    }
    
    struct Message: XPCByteProtocol {
        let messageId: UInt64
        let payload: Payload
        
        init(_ messageId: UInt64, _ payload: Payload) {
            self.messageId = messageId
            self.payload = payload
        }
        
        func bytes() -> Data {
            var data = Data()
            data.append(withUnsafeBytes(of: messageId) { Data($0) })
            data.append(payload.bytes())
            return data
        }
    }
    
    struct Payload: XPCByteProtocol {
        let magic: UInt32 = 0x42133742
        let protocol_version: UInt32 = 0x00000005
        let obj: XPCObjectProtocol
        
        init(_ obj: XPCObjectProtocol) {
            self.obj = obj
        }
        
        func bytes() -> Data {
            var data = Data()
            data.append(withUnsafeBytes(of: magic) { Data($0) })
            data.append(withUnsafeBytes(of: protocol_version) { Data($0) })
            data.append(obj.bytes())
            return data
        }
    }
}

protocol XPCByteProtocol {
    func bytes() -> Data
}

protocol XPCObjectProtocol: XPCByteProtocol {
    var type: XPC.MessageType { get }
}

extension XPC {
    struct _Array: XPCObjectProtocol {
        var type: XPC.MessageType { .array }
        let count: UInt32
        let entries: [XPCObjectProtocol]
        
        init(_ entries: [XPCObjectProtocol]) {
            self.count = UInt32(entries.count)
            self.entries = entries
        }
        
        func bytes() -> Data {
            var data = Data()
            data.append(type.byte)
            data.append(
                withUnsafeBytes(of: count) { Data($0) }
            )
            entries.forEach { entry in
                data.append(entry.bytes())
            }
            return data
        }
    }
    
    struct _Dictionary: XPCObjectProtocol {
        struct Entry: XPCByteProtocol {
            let key: String
            let value: XPCObjectProtocol
            func bytes() -> Data {
                var data = Data()
                data.append(key.data(4))
                data.append(value.bytes())
                return data
            }
        }
        
        var type: XPC.MessageType { .dictionary }
        let count: UInt32
        let entries: [Entry]
        
        init(_ entries: [Entry]) {
            self.count = UInt32(entries.count)
            self.entries = entries
        }
        
        func bytes() -> Data {
            var data = Data()
            data.append(type.byte)
            data.append(withUnsafeBytes(of: count) { Data($0) })
            entries.forEach { entry in
                data.append(entry.bytes())
            }
            return data
        }
    }
    
    struct _String: XPCObjectProtocol {
        var type: XPC.MessageType { .string }
        let value: String
        
        func bytes() -> Data {
            value.data(4)
        }
    }
    
    struct _Int64: XPCObjectProtocol {
        var type: XPC.MessageType { .int64 }
        let value: Int64
        
        func bytes() -> Data {
            withUnsafeBytes(of: value) { Data($0) }
        }
    }
    
    struct _UInt64: XPCObjectProtocol {
        var type: XPC.MessageType { .uint64 }
        let value: UInt64
        
        func bytes() -> Data {
            withUnsafeBytes(of: value) { Data($0) }
        }
    }
    
    struct _Double: XPCObjectProtocol {
        var type: XPC.MessageType { .double }
        let vlaue: Double
        
        func bytes() -> Data {
            withUnsafeBytes(of: vlaue) { Data($0) }
        }
    }
    
    struct _Bool: XPCObjectProtocol {
        var type: XPC.MessageType { .bool }
        let value: UInt32
        
        func bytes() -> Data {
            withUnsafeBytes(of: value) { Data($0) }
        }
    }
    
    struct _NULL: XPCObjectProtocol {
        var type: XPC.MessageType { .null }
        
        func bytes() -> Data {
            Data()
        }
    }
    
    struct _UUID: XPCObjectProtocol {
        var type: XPC.MessageType { .uuid }
        let value: UUID
        
        func bytes() -> Data {
            withUnsafeBytes(of: value.uuid) { Data($0) }
        }
    }
    
    struct _Pointer: XPCObjectProtocol {
        var type: XPC.MessageType { .pointer }

        func bytes() -> Data {
            Data()
        }
    }
    
    struct _Date: XPCObjectProtocol {
        var type: XPC.MessageType { .date }
        let value: UInt64
        
        func bytes() -> Data {
            withUnsafeBytes(of: value) { Data($0) }
        }
    }
    
    struct _Data: XPCObjectProtocol {
        var type: XPC.MessageType { .data }
        let value: Data
        
        func bytes() -> Data {
            value
        }
    }
    
    struct _FD: XPCObjectProtocol {
        var type: XPC.MessageType { .fd }
        let value: UInt32
        
        func bytes() -> Data {
            withUnsafeBytes(of: value) { Data($0) }
        }
    }
    
    struct Shmem: XPCObjectProtocol {
        var type: XPC.MessageType { .shmem }
        let length: UInt32
        let value: UInt32
        
        func bytes() -> Data {
            var data = Data()
            data.append(withUnsafeBytes(of: length) { Data($0) })
            data.append(withUnsafeBytes(of: value) { Data($0) })
            return data
        }
    }
    
    struct FileTransfer: XPCObjectProtocol {
        var type: XPC.MessageType { .fileTransfer }
        let msg_id: UInt64
        let data: XPCObjectProtocol

        func bytes() -> Data {
            var data = Data()
            data.append(withUnsafeBytes(of: msg_id) { Data($0) })
            data.append(self.data.bytes())
            return data
        }
    }
}

extension XPC {
    struct MessageType: OptionSet {
        let rawValue: UInt32
        
        var byte: Data {
            withUnsafeBytes(of: rawValue) { Data($0) }
        }
        
        static let null = MessageType(rawValue: 0x00001000)
        static let bool = MessageType(rawValue: 0x00002000)
        static let int64 = MessageType(rawValue: 0x00003000)
        static let uint64 = MessageType(rawValue: 0x00004000)
        static let double = MessageType(rawValue: 0x00005000)
        static let pointer = MessageType(rawValue: 0x00006000)
        static let date = MessageType(rawValue: 0x00007000)
        static let data = MessageType(rawValue: 0x00008000)
        static let string = MessageType(rawValue: 0x00009000)
        static let uuid = MessageType(rawValue: 0x0000a000)
        static let fd = MessageType(rawValue: 0x0000b000)
        static let shmem = MessageType(rawValue: 0x0000c000)
        static let machSend = MessageType(rawValue: 0x0000d000)
        static let array = MessageType(rawValue: 0x0000e000)
        static let dictionary = MessageType(rawValue: 0x0000f000)
        static let error = MessageType(rawValue: 0x00010000)
        static let connection = MessageType(rawValue: 0x00011000)
        static let endpoint = MessageType(rawValue: 0x00012000)
        static let serializer = MessageType(rawValue: 0x00013000)
        static let pipe = MessageType(rawValue: 0x00014000)
        static let machRecv = MessageType(rawValue: 0x00015000)
        static let bundle = MessageType(rawValue: 0x00016000)
        static let service = MessageType(rawValue: 0x00017000)
        static let serviceInstance = MessageType(rawValue: 0x00018000)
        static let activity = MessageType(rawValue: 0x00019000)
        static let fileTransfer = MessageType(rawValue: 0x0001a000)
    }

    struct Flags: OptionSet {
        let rawValue: UInt32

        static let alwaysSet = Flags(rawValue: 0x00000001)
        static let ping = Flags(rawValue: 0x00000002)
        static let dataPresent = Flags(rawValue: 0x00000100)
        static let wantingReply = Flags(rawValue: 0x00010000)
        static let reply = Flags(rawValue: 0x00020000)
        static let fileTxStreamRequest = Flags(rawValue: 0x00100000)
        static let fileTxStreamResponse = Flags(rawValue: 0x00200000)
        static let initHandshake = Flags(rawValue: 0x00400000)
    }
}
