//
//  Logger.swift
//  DeepReader
//
//  Centralized logging service
//

import Foundation
import os.log

/// Log levels for filtering
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

/// Centralized logging service using OSLog
final class Logger {
    static let shared = Logger()

    private let osLog: OSLog

    private init() {
        osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DeepReader", category: "App")
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }

    private func log(_ level: LogLevel, _ message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"

        let osLogType: OSLogType
        switch level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        }

        os_log("%{public}@", log: osLog, type: osLogType, formattedMessage)

        #if DEBUG
        print(formattedMessage)
        #endif
    }
}
