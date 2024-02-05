//
//  Connection.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/1/22.
//

import AppKit
import Network

let ROOT_CHANNEL: UInt64 = 1
let REPLY_CHANNEL: UInt64 = 3

class Connection: NSObject {
    lazy var wrapper = XPC.Adopter()
    lazy var bonjour = Bonjour()
    var connection: NWConnection? = nil
    
    lazy var message_id_map: [UInt64 : UInt64] = [:]
    
    var root_message_id = 0
    var reply_message_id = 0
}

extension Connection: NetServiceDelegate {
    func search() {
        self.bonjour.search { [weak self] service in
            self?.connect(service)
        }
    }
    
    func connect(_ service: NetService) {
        guard let addressData = service.addresses?.first else { return }
        
        var storage = sockaddr_storage()
        addressData.withUnsafeBytes {
            memcpy(&storage, $0.baseAddress!, min(MemoryLayout<sockaddr_storage>.size, addressData.count))
        }
        
        if Int32(storage.ss_family) == AF_INET6 {  // Check for IPv6
            let addr6 = withUnsafePointer(to: &storage) {
                $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    $0.pointee
                }
            }
            
            let ipStringBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET6_ADDRSTRLEN))
            var addr = addr6.sin6_addr
            inet_ntop(AF_INET6, &addr, ipStringBuffer, __uint32_t(INET6_ADDRSTRLEN))
            print("IPv6 address: \(String(cString: ipStringBuffer)) scope id: \(addr6.sin6_scope_id)")
            
            let interfaceIndex = addr6.sin6_scope_id
            let ifNameBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(IF_NAMESIZE))
            if_indextoname(interfaceIndex, ifNameBuffer)
            let interfaceName = String(cString: ifNameBuffer)
            let address = String(cString: ipStringBuffer) + "%" + interfaceName
            print(address)
            self.connection(address, 58783)
        }
    }
    
    func connection(_ host: String, _ port: UInt16) {
        self.connection?.forceCancel()
        let connection = NWConnection(to: .hostPort(host: .ipv6(.init(host)!), port: .init(rawValue: port)!), using: .tcp)
        self.connection = connection
        connection.start(queue: .main)
        connection.stateUpdateHandler = { state in
            print(state)
        }
        
        self.send(HTTP2.Magic)
        self.send(HTTP2.Frame.Settings([.MAX_CONCURRENT_STREAMS(100),
                                        .INITIAL_WINDOW_SIZE(1048576)])
            .serialize()
        )
        
        self.send(HTTP2.Frame.WindowUpdate(983041)
            .serialize())
        
        self.send(HTTP2.Frame.Headers()
            .flag("END_HEADERS")
            .streamId(Int(ROOT_CHANNEL))
            .serialize()
        )
                
        self.send(HTTP2.Frame.Datas(self.wrapper.creat(root_message_id, [:]))
            .serialize()
        )
        
        self.send(HTTP2.Frame.Datas().xpc(.creat { make in
            make.object(XPC._NULL())
                .message(0)
                .flags(.init(rawValue: 0x201))
        }).streamId(Int(ROOT_CHANNEL)).serialize())
        
        self.root_message_id += 1
        self.send(HTTP2.Frame.Headers()
            .streamId(Int(REPLY_CHANNEL))
            .flag("END_HEADERS")
            .serialize()
        )
        
        self.send(HTTP2.Frame.Datas(XPC.Wrapper.data { make in
            make.object(XPC._NULL())
            make.message(REPLY_CHANNEL)
            make.flags([.initHandshake, .alwaysSet])
        }).serialize())

        self.send(HTTP2.Frame.Settings([])
            .flag("ACK")
            .serialize()
        )
    }

    func receiveFrame() {
        
    }
    
    func receive(_ count: Int) {
        connection?.receive(minimumIncompleteLength: count, maximumLength: .max) { content, contentContext, isComplete, error in
            
            print("isComplete:\(isComplete)")
            
            if let error = error {
                print(error)
            }
        }
    }
    
    func send(_ data: Data?) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error {
                print("sendError - \(error)")
            }
        }))
    }
}

extension String {
    func data(_ alignment: Int) -> Data {
        guard var data = self.data(using: .utf8) else { return Data() }
        let remainder = data.count % alignment
        if remainder == 0 {
            return data
        }
        
        let padding = alignment - remainder
        for _ in 0 ..< padding {
            data.append(0)
        }
        return data
    }
}

extension Data {
    @discardableResult
    func code(_ closure: (Self) -> Void) -> Self {
        closure(self)
        return self
    }
}
