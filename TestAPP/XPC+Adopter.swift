//
//  XPC.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/4.
//

import AppKit

struct XPC { }

extension XPC {
    class Adopter {
        func creat(_ message_id: Int, _ payload: Any?, _ need_reply: Bool = false) -> Data {
            var flags = XPC.Flags.alwaysSet

            if payload != nil {
                flags = [flags, XPC.Flags.dataPresent]
            }
            
            if need_reply {
                flags = [flags, XPC.Flags.wantingReply]
            }
            
            let payload = XPC.Payload(buildXPCObject(payload))
            let message = XPC.Message(UInt64(message_id), payload)
            let wrapper = XPC.Wrapper(flags, message)
            return wrapper.bytes()
        }
        
        func buildXPCObject(_ value: Any?) -> XPCObjectProtocol {
            guard let value else {
                return XPC._NULL()
            }
            
            if let dic = value as? [String : Any] {
                let entries: [XPC._Dictionary.Entry] = dic.compactMap { item in
                    let value = buildXPCObject(item.value)
                    return .init(key: item.key, value: value)
                }
                return XPC._Dictionary(entries)
            }
            
            if let array = value as? [Any] {
                let entries = array.compactMap { value in
                   return buildXPCObject(value)
                }
                return XPC._Array(entries)
            }
            
            if value is Int || value is Int32 || value is Int64, let value = value as? Int64 {
                return XPC._Int64(value: value)
            }
            
            if value is UInt || value is UInt32 || value is UInt64, let value = value as? UInt64 {
                return XPC._UInt64(value: value)
            }
            
            if value is Bool, let value = value as? Bool {
                return XPC._Bool(value: value ? 1 : 0)
            }
            
            if value is String, let value = value as? String {
                return XPC._String(value: value)
            }
            
            if value is Data, let value = value as? Data {
                return XPC._Data(value: value)
            }
            
            if value is CGFloat || value is Double, let value = value as? Double  {
                return XPC._Double(vlaue: value)
            }
            
            if let value = value as? UUID {
                return XPC._UUID(value: value)
            }
            
            return XPC._NULL()
        }
    }
}
