//
//  HTTP2.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/4.
//

import Foundation

extension HTTP2 {
    struct Frame { }
}

protocol HTTP2FrameProtocol: AnyObject {
    var stream_id: Int { get set }
    var define_flags: [HTTP2.Flag] { get }
    var flags: [HTTP2.Flag] { get set }
    var type: Int { get }
    
    func serializeBody() -> Data
    func flag(_ name: String) -> Self
    func streamId(_ id: Int) -> Self
}

extension HTTP2FrameProtocol {
    func flag(_ name: String) -> Self {
        if self.flags.contains(where: { item in
            item.name == name
        }) { return self }
        
        if let item = self.define_flags.first(where: { item in
            return item.name == name
        }) {
            self.flags.append(item)
        }
        return self
    }
    
    func streamId(_ id: Int) -> Self {
        self.stream_id = id
        return self
    }
    
    func serialize() -> Data {
        var outputData = Data()
        let body = serializeBody()
        let body_len = body.count
        
        var flags: UInt8 = 0
        self.flags.forEach { flag in
            flags |= flag.bit
        }
        
        var header = Data()
        let bodyLenUpper = UInt8((body_len >> 8) & 0xFFFF)
        let bodyLenLower = UInt8(body_len & 0xFF)
        let streamIdData = withUnsafeBytes(of: (stream_id & 0x7FFFFFFF).bigEndian) { Data($0) }
        let type = withUnsafeBytes(of: type) { Data($0) }
        
        header.append(bodyLenUpper)
        header.append(bodyLenLower)
        header.append(type)
        header.append(flags)
        header.append(streamIdData)
        
        outputData.append(header)
        outputData.append(body)
        
        return outputData
    }
}

extension HTTP2.Frame {
    class Datas: HTTP2FrameProtocol {
        var type: Int = 0x0
        var stream_id: Int = 0
        var flags: [HTTP2.Flag] = []
        var define_flags: [HTTP2.Flag] = [
            .init("END_STREAM", 0x01),
            .init("PADDED", 0x08),
        ]
                
        var data: Data
        var pad_length = 0

        init(_ data: Data = Data()) {
            self.data = data
        }
        
        func serializeBody() -> Data {
            let paddingData = self.serializePaddingData()
            let padding = Data(count: self.pad_length)
            let result = paddingData + self.data + padding
            return result
        }
        
        fileprivate func serializePaddingData() -> Data {
            if self.flags.contains(where: { $0.name == "PADDED" }) {
                let padLength = UInt8(self.pad_length)
                let data = withUnsafeBytes(of: padLength.bigEndian) { Data($0) }
                return data
            }
            return Data()
        }
        
        @discardableResult
        public func data(_ value: Data) -> Self {
            self.data = value
            return self
        }
    }
    
    class Headers: HTTP2FrameProtocol {
        var type: Int = 0x01
        var stream_id: Int = 0
        var flags: [HTTP2.Flag] = []
        var define_flags: [HTTP2.Flag] = [
            .init("END_STREAM", 0x01),
            .init("END_HEADERS", 0x04),
            .init("PADDED", 0x08),
            .init("PRIORITY", 0x20),
        ]
        
        var data: Data
        var pad_length = 0
        var depends_on: UInt32 = 0x0
        var stream_weight: UInt8 = 0x0
        var exclusive: Bool = false
        
        init(_ data: Data = Data()) {
            self.data = data
        }
        
        func serializeBody() -> Data {
            let paddingData = self.serializePaddingData()
            let padding = Data(count: self.pad_length)
            var priorityData: Data
            
            if self.flags.contains(where: { $0.name == "PRIORITY" }) {
                priorityData = self.serializePriorityData()
            } else {
                priorityData = Data()
            }
           
            let result = paddingData + priorityData + self.data + padding
            return result
        }
        
        fileprivate func serializePaddingData() -> Data {
            if self.flags.contains(where: { $0.name == "PADDED" }) {
                let padLength = UInt8(self.pad_length)
                let data = withUnsafeBytes(of: padLength.bigEndian) { Data($0) }
                return data
            }
            return Data()
        }
        
        fileprivate func serializePriorityData() -> Data {
            var value = self.depends_on

            if self.exclusive {
                value += 0x80000000
            }

            var data = Data()
            let dataValue = withUnsafeBytes(of: value) { Data($0) }
            data.append(dataValue)
            data.append(self.stream_weight)
            return data
        }
    }
        
    class Settings: HTTP2FrameProtocol {
        enum P {
            case HEADER_TABLE_SIZE(Int)
            case ENABLE_PUSH(Int)
            case MAX_CONCURRENT_STREAMS(Int)
            case INITIAL_WINDOW_SIZE(Int)
            case MAX_FRAME_SIZE(Int)
            case MAX_HEADER_LIST_SIZE(Int)
            case ENABLE_CONNECT_PROTOCOL(Int)
            
            var body: (key: Int, value: Int) {
                switch self {
                    case .HEADER_TABLE_SIZE(let value):
                        return (0x01, value)
                    case .ENABLE_PUSH(let value):
                        return (0x02, value)
                    case .MAX_CONCURRENT_STREAMS(let value):
                        return (0x03, value)
                    case .INITIAL_WINDOW_SIZE(let value):
                        return (0x04, value)
                    case .MAX_FRAME_SIZE(let value):
                        return (0x05, value)
                    case .MAX_HEADER_LIST_SIZE(let value):
                        return (0x06, value)
                    case .ENABLE_CONNECT_PROTOCOL(let value):
                        return (0x08, value)
                }
            }
        }
        
        var type: Int = 0x04
        var stream_id: Int = 0
        var flags: [HTTP2.Flag] = []
        var define_flags: [HTTP2.Flag] = [
            .init("ACK", 0x01)
        ]
        
        var parameters: [P]
        
        init(_ parameters: [P]) {
            self.parameters = parameters
        }
        
        func serializeBody() -> Data {
            var data = Data()
            parameters.forEach { setting in
                let body = setting.body
                let settingKey = UInt16(body.key & 0xFF)
                let settingData = withUnsafeBytes(of: settingKey.bigEndian) { Data($0) }
                let valueData = withUnsafeBytes(of: body.value.bigEndian) { Data($0) }
                data.append(settingData)
                data.append(valueData)
            }
            return data
        }
    }
    
    class WindowUpdate: HTTP2FrameProtocol {
        var type: Int = 0x08
        var stream_id: Int = 0
        var flags: [HTTP2.Flag] = []
        var define_flags: [HTTP2.Flag] = []
        
        var window_increment: Int = 0
        
        init(_ window_increment: Int) {
            self.window_increment = window_increment
        }
        
        func serializeBody() -> Data {
            let windowIncrement = UInt32(self.window_increment & 0x7FFFFFFF)
            let data = withUnsafeBytes(of: windowIncrement.bigEndian) { Data($0) }
            return data
        }
    }
}
