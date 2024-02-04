//
//  Connection.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/1/22.
//

import CoreFoundation
import Network
//import

class Connection: NSObject {
    lazy var bonjour = Bonjour()
    var connection: NWConnection? = nil
    
    lazy var dtx = DTXMessageHandle()
}

extension Connection {
    func interfaces() {
        var ifaddr : UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return }
        guard let firstAddr = ifaddr else { return }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
                        
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ptr.pointee.ifa_addr, 
                                   socklen_t(addr.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0),
                                   NI_NUMERICHOST) == 0 {
                        if let address = String(cString: hostname, encoding: .utf8) {
                            print("interface: \(String(cString: ptr.pointee.ifa_name)), address: \(address)")
                        }
                    }
                }
            }
        }

        freeifaddrs(ifaddr)
    }
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
        let connection = NWConnection(to: .hostPort(host: .ipv6(.init(host)!), port: .init(rawValue: port)!), using: .quic(alpn: []))
        connection.start(queue: .main)
        connection.stateUpdateHandler = { state in
            print(state)
        }
         
        self.send(HTTP2.Magic)
        self.send(HTTP2.Frame.Settings([
            .MAX_CONCURRENT_STREAMS(100),
            .INITIAL_WINDOW_SIZE(1048576),
        ]).serialize())
        self.send(HTTP2.Frame.WindowUpdate(983041).serialize())
        self.send(HTTP2.Frame.Headers().flag("END_HEADERS").serialize())
        
        self.connection = connection
    }
    
    func send(_ data: Data?) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error {
                print("sendError - \(error)")
            }
        }))
    }
}
