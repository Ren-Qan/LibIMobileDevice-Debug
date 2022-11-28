//
//  IInstrumentsCPU.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/28.
//

import Cocoa

class IInstrumentsCPU: IInstrumentsBaseService, IInstrumentsServiceProtocol {
    
}

extension IInstrumentsCPU {
    var server: IInstrumentsServiceName {
        return .sysmontap
    }
        
    func args(selector: String) -> DTXArguments? {
        if selector == "setConfig:" {
            let config: [String : Any] = [
                "bm": 0,
                "cpuUsage": true,
                "ur": 1000,
                "sampleInterval": 1000000000,
                "procAttrs": [
                    "memVirtualSize", "cpuUsage", "ctxSwitch", "intWakeups", "physFootprint", "memResidentSize", "memAnon", "pid"
                ],
                "sysAttrs": [
                    "vmExtPageCount", "vmFreeCount", "vmPurgeableCount", "vmSpeculativeCount", "physMemSize"
                ]
            ]
            let args = DTXArguments()
            args.add(config)
            return args
        }
        return nil
    }
}
