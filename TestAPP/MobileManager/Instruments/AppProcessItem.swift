//
//  AppProcessItem.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/24.
//

import Cocoa

struct AppProcessItem {
    var isApplication = false
    var name = ""
    var pid: UInt = 0
    var realAppName = ""
    var startDate: Date?
}
