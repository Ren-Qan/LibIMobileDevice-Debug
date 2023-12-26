//
//  RSDService.swift
//  TestAPP
//
//  Created by 任玉乾 on 2023/12/19.
//

import Cocoa
import Network

class RSDService: NSObject {
    fileprivate lazy var bonjour = Bonjour()
    
    fileprivate var connection: NWConnection? = nil
}

extension RSDService {
    func start() {
        connection?.cancel()
        bonjour.search { [weak self] service in
            self?.connect(service)
        }
    }
}

extension RSDService {
    fileprivate func connect(_ service: NetService) {
        guard let data = service.addresses?.first,
              let ipv6String = dataToIPv6String(data),
              let ipv6 = IPv6Address(ipv6String),
              let hostName = service.hostName,
              let port = NWEndpoint.Port(rawValue: UInt16(service.port)) else { return }
        
        let host = NWEndpoint.Host.ipv6(ipv6)
        let connection = NWConnection(host: host, port: port, using: .quic(alpn: []))
        self.connection = connection
        connection.stateUpdateHandler = { state in
            print(state)
        }
        connection.start(queue: .global())
        
        
        
        let http2Magic: Data = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".data(using: .utf8)!
        self.send(http2Magic)
    }
 
//    private func send(paylod: HTTP2Frame.FramePayload) {
//        
//    }
    
    private func send(object: Any) {
        if let data = try? JSONSerialization.data(withJSONObject: object) {
            send(data)
        } else {
            print(object)
        }
    }
    
    private func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            print(error)
        }))
    }
    
    func dataToIPv6String(_ data: Data) -> String? {
        var storage = sockaddr_in6()

        // 复制数据到本地变量
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress else {
                return
            }

            memcpy(&storage.sin6_addr, baseAddress, min(MemoryLayout.size(ofValue: storage.sin6_addr), data.count))
        }

        // 为 IPv6 地址的范围标识符（Scope ID）分配足够的空间
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN) + Int(IF_NAMESIZE))
        guard let result = inet_ntop(AF_INET6, &storage, &buffer, socklen_t(INET6_ADDRSTRLEN)) else {
            return nil
        }

        return String(cString: result)
    }
}
