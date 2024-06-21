//
//  DisableableLogger.swift
//
//
//  Created by DOYEON LEE on 6/21/24.
//

import Foundation
import OSLog

/**
 `DisableableLogger` is a logger that can be enabled or disabled based on a flag.
 
 This class wraps around the `Logger` from the `os` framework, providing methods to log messages at different levels (debug, info, error, fault). The logging can be conditionally disabled by setting a flag. 
 
 You can determine the initial state of logging (enabled or disabled) using the `isDisabled` parameter during initialization and dynamically change it using the ``disabled(_:)`` method.
 
 - Important: By default, logging is enabled.
*/
class DisableableLogger {
    private let logger: Logger
    private var isDisabled: Bool
    
    init(subsystem: String, category: String, isDisabled: Bool = false) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.isDisabled = isDisabled
    }

    func log(_ message: String, type: OSLogType = .default) {
        if isDisabled { return }
        logger.log(level: type, "\(message, privacy: .public)")
    }
    
    func debug(_ message: String) {
        log(message, type: .debug)
    }
    
    func info(_ message: String) {
        log(message, type: .info)
    }
    
    func error(_ message: String) {
        log(message, type: .error)
    }
    
    func fault(_ message: String) {
        log(message, type: .fault)
    }
}

extension DisableableLogger {
    func disabled(_ disabled: Bool = true) {
        self.isDisabled = disabled
    }
}
