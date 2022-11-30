//
//  IInstrumentsRuningProcess.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/29.
//

import Cocoa

enum IInstrumentsDeviceInfoArgs: IInstrumentRequestArgsProtocol {
    case runningProcesses
    
    var selector: String {
        switch self {
            case .runningProcesses:
                return "runningProcesses"
        }
    }
    
    var args: DTXArguments? {
        return nil
    }
}

class IInstrumentsDeviceInfo: IInstrumentsBaseService {

}

extension IInstrumentsDeviceInfo: IInstrumentsServiceProtocol {
    typealias Arg = IInstrumentsDeviceInfoArgs
    
    var server: IInstrumentsServiceName {
        return .deviceinfo
    }

    func response(_ response: DTXReceiveObject?) {
        if let object = response?.object {
            print(object)
        }
    }
}
