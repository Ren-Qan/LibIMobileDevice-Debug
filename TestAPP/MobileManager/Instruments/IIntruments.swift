//
//  IIntruments.swift
//  TestAPP
//
//  Created by 任玉乾 on 2022/11/24.
//

import Cocoa
import LibMobileDevice

enum IIntrumentsServerName: String {
    case deviceinfo = "com.apple.instruments.server.services.deviceinfo"
    case sysmontap = "com.apple.instruments.server.services.sysmontap"
}

protocol IIntrumentsDelegate: NSObjectProtocol {
    func appProcess(list: [AppProcessItem])
    
    func cpu(info: [[String : Any]])
}

class IIntruments: NSObject {
    // MARK: - Private -
    private lazy var dtxService: DTXMessageHandle = {
        let server = DTXMessageHandle()
        server.delegate = self
        return server
    }()
    
    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private lazy var resolver = IIntrumentsResolver()
    
    private var timer: Timer? = nil
    
    // MARK: - Public Getter -
    public private(set) var isConnected = false
    
    // MARK: - Public -
    
    public weak var delegate: IIntrumentsDelegate? = nil {
        didSet {
            resolver.sourceDelegate = delegate
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Private -
private extension IIntruments {
    func request(_ server: IIntrumentsServerName, _ selector: String, _ args: DTXArguments?) {
        queue.addOperation { [weak self] in
            self?.dtxService.request(forServer: server.rawValue, selector: selector, args: args)
        }
    }
}

extension IIntruments {
    func stop() {
        queue.addOperation { [weak self] in
            self?.isConnected = false
            self?.dtxService.stopService()
        }
    }
    
    @discardableResult
    func start(_ device: IDevice) -> Bool {
        guard let device_t = device.device_t else {
            return false
        }
        
        isConnected = dtxService.connectInstrumentsService(withDevice: device_t)
        return isConnected
    }
    
    func response() {
        queue.addOperation { [weak self] in
            self?.dtxService.responseForReceive()
        }
    }
    
    func autoReponse(_ seconds: TimeInterval) {
        timer?.invalidate()
        timer = nil
        
        let timer = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
            self?.response()
        }
        
        timer.fire()
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    
    func refreshAppProcessList() {
        let selector = "runningProcesses"
        request(.deviceinfo, selector, nil)
    }
    
    func cpu() {
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
        
        request(.sysmontap, "setConfig:", args)
        request(.sysmontap, "start", nil)
    }
    
    func gpu() {
        
    }
}

extension IIntruments: DTXMessageHandleDelegate {
    func responseServer(_ server: DTXServerModel, object: DTXReceiveObject, handle: DTXMessageHandle) {
        resolver.resolver(server: server, object: object)
    }
    
    func error(_ error: String, handle: DTXMessageHandle) {
        
    }
}
