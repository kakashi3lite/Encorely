import Foundation
import os.log

// MARK: - Professional Logging System
public enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    public var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Logging Categories
public enum LogCategory: String, CaseIterable {
    case audio = "Audio"
    case ui = "UI"
    case network = "Network"
    case performance = "Performance"
    case security = "Security"
    case general = "General"
    
    public var subsystem: String {
        return "com.encorely.app"
    }
}

// MARK: - Professional Logger
public struct EncorelyLogger {
    
    private let category: LogCategory
    private let osLog: OSLog
    
    public init(category: LogCategory) {
        self.category = category
        self.osLog = OSLog(subsystem: category.subsystem, category: category.rawValue)
    }
    
    // MARK: - Logging Methods
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(level: .error, message: fullMessage, file: file, function: function, line: line)
    }
    
    public func critical(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Critical Error: \(error.localizedDescription)"
        }
        log(level: .critical, message: fullMessage, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(level.rawValue)] \(fileName):\(line) \(function) - \(message)"
        
        os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        
        // Also send to console in debug builds
        #if DEBUG
        print(logMessage)
        #endif
        
        // Send critical errors to crash reporting service
        if level == .critical {
            reportCriticalError(message: message, file: fileName, function: function, line: line)
        }
    }
    
    private func reportCriticalError(message: String, file: String, function: String, line: Int) {
        // Integration point for crash reporting services (Crashlytics, Sentry, etc.)
        // For now, we'll ensure it's logged to system
        let criticalMessage = "CRITICAL ERROR in \(file):\(line) \(function) - \(message)"
        NSLog(criticalMessage)
    }
}

// MARK: - Global Logger Instances
public extension EncorelyLogger {
    static let audio = EncorelyLogger(category: .audio)
    static let ui = EncorelyLogger(category: .ui)
    static let network = EncorelyLogger(category: .network)
    static let performance = EncorelyLogger(category: .performance)
    static let security = EncorelyLogger(category: .security)
    static let general = EncorelyLogger(category: .general)
}

// MARK: - Performance Logging
public extension EncorelyLogger {
    
    func measurePerformance<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        info("Performance: \(operation) completed in \(String(format: "%.3f", timeElapsed * 1000))ms")
        
        // Log performance warnings for slow operations
        if timeElapsed > 0.1 { // 100ms threshold
            warning("Performance: \(operation) took \(String(format: "%.3f", timeElapsed * 1000))ms (>100ms threshold)")
        }
        
        return result
    }
    
    func measureAsyncPerformance<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        info("Async Performance: \(operation) completed in \(String(format: "%.3f", timeElapsed * 1000))ms")
        
        if timeElapsed > 0.1 {
            warning("Async Performance: \(operation) took \(String(format: "%.3f", timeElapsed * 1000))ms (>100ms threshold)")
        }
        
        return result
    }
}

// MARK: - Memory Logging
public extension EncorelyLogger {
    
    func logMemoryUsage(_ context: String) {
        let memoryUsage = getMemoryUsage()
        info("Memory Usage [\(context)]: \(String(format: "%.1f", memoryUsage))MB")
        
        if memoryUsage > 100 {
            warning("High memory usage [\(context)]: \(String(format: "%.1f", memoryUsage))MB")
        }
        
        if memoryUsage > 200 {
            critical("Critical memory usage [\(context)]: \(String(format: "%.1f", memoryUsage))MB")
        }
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return 0
        }
        
        return Double(info.resident_size) / (1024.0 * 1024.0)
    }
}

// MARK: - Error Logging Extensions
public extension Error {
    func log(to logger: EncorelyLogger, message: String? = nil, level: LogLevel = .error) {
        let errorMessage = message ?? "Error occurred"
        
        switch level {
        case .debug:
            logger.debug("\(errorMessage): \(localizedDescription)")
        case .info:
            logger.info("\(errorMessage): \(localizedDescription)")
        case .warning:
            logger.warning("\(errorMessage): \(localizedDescription)")
        case .error:
            logger.error(errorMessage, error: self)
        case .critical:
            logger.critical(errorMessage, error: self)
        }
    }
}