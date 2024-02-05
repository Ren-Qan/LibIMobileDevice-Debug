//
//  HTTP2.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/5.
//

import AppKit

struct HTTP2 {
    static let Magic = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".data(using: .utf8)!
}
