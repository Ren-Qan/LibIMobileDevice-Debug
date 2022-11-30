//
//  IInstrumentsCPU.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/28.
//

import Cocoa

enum IInstrumentsSysmontapArgs: IInstrumentRequestArgsProtocol {
    case setConfig
    
    case start
    
    var selector: String {
        switch self {
            case .setConfig:
                return "setConfig:"
            case .start:
                return "start"
        }
    }
    
    var args: DTXArguments? {
        if self == .setConfig {
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

class IInstrumentsSysmontap: IInstrumentsBaseService  {
    
}

extension IInstrumentsSysmontap: IInstrumentsServiceProtocol {
    typealias Arg = IInstrumentsSysmontapArgs
    
    var server: IInstrumentsServiceName {
        return .sysmontap
    }
    
    func response(_ response: DTXReceiveObject?) {
        if let result = response?.object {
            print(result)
        }
    }
}
