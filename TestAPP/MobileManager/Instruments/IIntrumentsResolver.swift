//
//  IIntrumentsResolver.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/24.
//

import Cocoa

class IIntrumentsResolver: NSObject {
    public weak var sourceDelegate: IIntrumentsDelegate? = nil
}

extension IIntrumentsResolver {
    func resolver(server: DTXServerModel,
                  object: DTXReceiveObject) {
        guard let name = IIntrumentsServerName(rawValue: server.server) else {
            return
        }
        
        switch name {
            case .sysmontap:
                cpu(object: object)
            case .deviceinfo:
                appProcessList(object: object)
        }
    }
}

private extension IIntrumentsResolver {
    func appProcessList(object: DTXReceiveObject) {
        guard let arr = object.object() as? [[String : Any]] else {
            return
        }
        
        var list = [AppProcessItem]()
        arr.forEach { item in
            list.append(.init(item))
        }
        sourceDelegate?.appProcess(list: list)
    }
    
    func cpu(object: DTXReceiveObject) {
        guard let infos = object.object() as? [[String : Any]] else {
            return
        }
        
        sourceDelegate?.cpu(info: infos)
    }
}


extension IIntrumentsDelegate {
    func appProcess(list: [AppProcessItem]) {
        
    }
    
    func cpu(info: [[String : Any]]) {
        
    }
}
