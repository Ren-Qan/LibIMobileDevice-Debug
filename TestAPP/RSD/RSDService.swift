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
        let hostName = service.hostName,
        let port = NWEndpoint.Port(rawValue: UInt16(58783)) else { return }
        
        let host = NWEndpoint.Host(hostName)
    
        let connection = NWConnection(host: host, port: port, using: .quic(alpn: []))
        self.connection = connection
        connection.stateUpdateHandler = { state in
            print(state)
        }
        connection.start(queue: .global())
        
        
        let HTTP2_MAGIC = Data([0x50, 0x52, 0x49, 0x20, 0x2a, 0x20, 0x48, 0x54, 0x54, 0x50, 0x2f, 0x32, 0x2e, 0x30, 0x0d, 0x0a, 0x0d, 0x0a, 0x53, 0x4d, 0x0d, 0x0a, 0x0d, 0x0a])
        let setting1 = try? JSONSerialization.data(withJSONObject: [0x03 : 100,
                                                                    0x04 : 1048576])
        
        send(HTTP2_MAGIC)
        send(setting1!)
    }
    
    private func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            print(error)
        }))
    }
}
