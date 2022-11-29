//
//  IInstrumentRunningProcessModel.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/29.
//

import Cocoa

struct IInstrumentRunningProcessModel {
    var isApplication: Bool? = nil
    var name: String? = nil
    var pid: UInt? = nil
    var realAppName: String? = nil
    var startDate: Date? = nil
    
    init(_ dic: [String : Any]) {
        isApplication = dic["isApplication"] as? Bool
        name = dic["name"] as? String
        pid = dic["pid"] as? UInt
        realAppName = dic["realAppName"] as? String
        startDate = dic["startDate"] as? Date
    }
}
