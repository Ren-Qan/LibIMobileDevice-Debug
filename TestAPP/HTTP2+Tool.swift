//
//  HTTP2+XPC.swift
//  TestAPP
//
//  Created by 任玉乾 on 2024/2/5.
//

import AppKit

extension HTTP2.Frame.Datas {
    func xpc(_ wrapper: XPC.Wrapper) -> Self {
        self.data = wrapper.bytes()
        return self
    }
}
