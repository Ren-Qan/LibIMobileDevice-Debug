//
//  IInstrumentsBaseService.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/28.
//

import Cocoa

class IInstrumentsBaseService: NSObject {
    public weak var instrumentHandle: IIntruments? = nil
    
    public private(set) var current_identifier: UInt32 = 0
    
    public var isStartSuccess = false
    
    public var next_identifier: UInt32 {
        current_identifier += 1
        return current_identifier
    }
    
    required override init() {
        super.init()
    }
}
