//
//  HTTP2+Flag.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/5.
//

import AppKit

extension HTTP2 {
    class Flag {
        var name: String
        var bit: UInt8
        
        init(_ name: String,
             _ bit: UInt8) {
            self.name = name
            self.bit = bit
        }
    }
}
