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
    fileprivate func connect1(_ netService: NetService) {
        
    }
    
    fileprivate func connect(_ netService: NetService) {
        netService.addresses?.forEach({ adress in
            adress.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> Void in
                guard let addr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr_in6.self) else { return }
                var add = addr.pointee.sin6_addr
                var addressStr = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                inet_ntop(AF_INET6, &add, &addressStr, socklen_t(INET6_ADDRSTRLEN))

                let ipString = String(cString: addressStr)
                print("name:\(netService.name) ip:" + ipString)
            }
        })
//
//        // 设置状态更新
//        connection?.stateUpdateHandler = { newState in
//            print(newState)
//            switch(newState) {
//            // Handle changes in connection state.
//            case .ready: print("Ready to send")
//            case .failed(let error): print("Failed with error \(error)")
//            default: break
//            }
//        }
//
//        // 启动连接
//        connection?.start(queue: .main)
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
