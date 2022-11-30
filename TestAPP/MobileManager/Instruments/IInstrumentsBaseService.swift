//
//  IInstrumentsBaseService.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/28.
//

import Cocoa

class IInstrumentsBaseService: NSObject {
    public weak var instrumentHandle: IIntruments? = nil
    
    public private(set) var currentIdentifier: UInt32 = 1
        
    public var nextIdentifier: UInt32 {
        currentIdentifier += 1
        return currentIdentifier
    }
    
    required override init() {
        super.init()
    }
}
