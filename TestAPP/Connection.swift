//
//  Connection.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/1/22.
//

import CoreFoundation
import Network
import NIO
import NIOHTTP2
import Darwin
import NIOPosix
import SwiftUI
//import

class Connection: NSObject {
    lazy var bonjour = Bonjour()
    var connection: NWConnection? = nil
    
    lazy var dtx = DTXMessageHandle()
}

extension Connection {
    func xpc(_ ip: String) {
    }
}

extension Connection {
    func nio(_ ip: String) {
    
    }
}

extension Connection {
    func build(_ ip: String) {
        self.connection?.forceCancel()
        self.connection = nil

        guard let address = IPv6Address(ip), let port = NWEndpoint.Port(rawValue: 58783) else { return }
        let endpoint = NWEndpoint.hostPort(host: .ipv6(address), port: port)
        let connection = NWConnection(to: endpoint, using: .quic(alpn: []))
        connection.start(queue: .main)
        connection.stateUpdateHandler = { state in
            print(state)
        }
        
        let HTTP2_MAGIC = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".data(using: .utf8)!
        send(HTTP2_MAGIC)
        
        let frame = HTTP2Frame(streamID: .init(0), payload: .settings(
            .settings(
                [HTTP2Setting(parameter: .maxConcurrentStreams, value: 100),
                 HTTP2Setting(parameter: .initialWindowSize,value: 1048576)])
        ))
        
        
        let handle = NIOHTTP2Handler(mode: .client)
        
        
        connection.receiveMessage { content, contentContext, isComplete, error in
            if let content, error == nil {
                print(content)
            }
        }
        
//        connection.requestEstablishmentReport(queue: .global()) { report in
//            print(report)
//        }
        
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
            self.host(address, 58783)
        }
    }
    
    func host(_ host: String, _ port: UInt16) {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.Types.SocketOption(level: SOL_SOCKET, name: SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.configureHTTP2Pipeline(mode: .client) { streamChannel in
                    streamChannel.pipeline.addHandler(TH())
                }.map { _ in }
            }

        defer {
            try! group.syncShutdownGracefully()
        }
        
        let connectionFuture = bootstrap.connect(host: host, port: Int(port))

        connectionFuture.whenFailure { error in
            print("Failed to connect: \(error)")
        }

        _ = try! connectionFuture.wait()
        print("Successfully connected to \(host):\(port)")
        
        
        connectionFuture.whenSuccess { channel in
            do {
                let multiplexer = try channel.pipeline.syncOperations.handler(type: HTTP2StreamMultiplexer.self)
                multiplexer.createStreamChannel(promise: nil) { streamChannel in
                    streamChannel.pipeline.addHandler(TH())
                }
                
                // Create reply channel
                multiplexer.createStreamChannel(promise: nil) { streamChannel in
                    streamChannel.pipeline.addHandler(TH())
                }
                
                let initialSettingsFrame = HTTP2Frame(streamID: .rootStream, payload: .settings(
                    .settings(
                        [HTTP2Setting(parameter: .maxConcurrentStreams, value: 100),
                         HTTP2Setting(parameter: .initialWindowSize,value: 1048576)])
                ))
                channel.writeAndFlush(initialSettingsFrame, promise: nil)

                let windowUpdateFrame = HTTP2Frame(streamID: .rootStream, payload: .windowUpdate(windowSizeIncrement: 983041))
                channel.writeAndFlush(windowUpdateFrame, promise: nil)
                
                channel.writeAndFlush(<#T##data: NIOAny##NIOAny#>, promise: <#T##EventLoopPromise<Void>?#>)
                
                channel.read()
                
//                let headersFrame = HTTP2Frame(streamID: 1, payload: .settings(.settings([.init(parameter: ., value: <#T##Int#>)])))
//                channel.writeAndFlush(headersFrame, promise: nil)
                
            } catch {
                
            }
        }
        
    }
}

class TH: ChannelHandler {
    func handlerAdded(context: ChannelHandlerContext) {
        print(#function)
        print(context)
    }

    /// Called when this `ChannelHandler` is removed from the `ChannelPipeline`.
    ///
    /// - parameters:
    ///     - context: The `ChannelHandlerContext` which this `ChannelHandler` belongs to.
    func handlerRemoved(context: ChannelHandlerContext) {
        print(#function)
        print(context)
    }
}

