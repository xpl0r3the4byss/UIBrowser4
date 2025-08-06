import Cocoa
import Combine

/// Centralized error handling system for UI Browser
@MainActor
class ErrorHandlingSystem {
    // MARK: - Types
    
    /// Error severity level
    enum Severity: Int, Comparable {
        case info
        case warning
        case error
        case critical
        
        static func < (lhs: Severity, rhs: Severity) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Error context information
    struct ErrorContext {
        let file: String
        let function: String
        let line: Int
        let timestamp: Date
        let operationName: String
        var retryCount: Int = 0
        var userInfo: [String: Any] = [:]
    }
    
    /// Error handling strategy
    enum Strategy {
        case ignore
        case retry(maxAttempts: Int)
        case fallback(operation: () async throws -> Void)
        case recover(transformation: (Error) async throws -> Void)
        case propagate
    }
    
    /// Handled error record
    struct ErrorRecord: Identifiable {
        let id = UUID()
        let error: Error
        let severity: Severity
        let context: ErrorContext
        let timestamp: Date
        let resolution: Resolution
        
        enum Resolution {
            case handled
            case retried(attempts: Int, success: Bool)
            case recovered
            case propagated
            case ignored
        }
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ErrorHandlingSystem()
    
    /// Error history
    private var errorHistory: [ErrorRecord] = []
    
    /// Error strategies
    private var strategies: [String: Strategy] = [:]
    
    /// Publishers
    let errorOccurredPublisher = PassthroughSubject<ErrorRecord, Never>()
    let criticalErrorPublisher = PassthroughSubject<ErrorRecord, Never>()
    
    /// Maximum history items
    private let maxHistoryItems = 1000
    
    // MARK: - Error Handling
    
    /// Handle error with context
    func handleError(_ error: Error, severity: Severity, context: ErrorContext) async throws {
        // Create error record
        let record = ErrorRecord(
            error: error,
            severity: severity,
            context: context,
            timestamp: Date(),
            resolution: .handled
        )
        
        // Add to history
        addToHistory(record)
        
        // Notify observers
        errorOccurredPublisher.send(record)
        if severity == .critical {
            criticalErrorPublisher.send(record)
        }
        
        // Apply strategy
        if let strategy = strategies[context.operationName] {
            try await applyStrategy(strategy, to: error, with: context)
        } else {
            // Default handling based on severity
            switch severity {
            case .info:
                logError(record)
            case .warning:
                logError(record)
                showWarning(record)
            case .error, .critical:
                logError(record)
                showError(record)
                throw error // Propagate severe errors
            }
        }
    }
    
    /// Register error handling strategy
    func registerStrategy(_ strategy: Strategy, for operation: String) {
        strategies[operation] = strategy
    }
    
    /// Apply error handling strategy
    private func applyStrategy(_ strategy: Strategy, to error: Error, with context: ErrorContext) async throws {
        var updatedContext = context
        
        switch strategy {
        case .ignore:
            let record = ErrorRecord(
                error: error,
                severity: .info,
                context: context,
                timestamp: Date(),
                resolution: .ignored
            )
            addToHistory(record)
            
        case .retry(let maxAttempts):
            updatedContext.retryCount += 1
            if updatedContext.retryCount <= maxAttempts {
                // Retry operation
                do {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(updatedContext.retryCount)) * 1_000_000_000))
                    let record = ErrorRecord(
                        error: error,
                        severity: .warning,
                        context: updatedContext,
                        timestamp: Date(),
                        resolution: .retried(attempts: updatedContext.retryCount, success: true)
                    )
                    addToHistory(record)
                } catch {
                    let record = ErrorRecord(
                        error: error,
                        severity: .error,
                        context: updatedContext,
                        timestamp: Date(),
                        resolution: .retried(attempts: updatedContext.retryCount, success: false)
                    )
                    addToHistory(record)
                    throw error
                }
            } else {
                throw error
            }
            
        case .fallback(let operation):
            do {
                try await operation()
                let record = ErrorRecord(
                    error: error,
                    severity: .warning,
                    context: context,
                    timestamp: Date(),
                    resolution: .recovered
                )
                addToHistory(record)
            } catch {
                throw error
            }
            
        case .recover(let transformation):
            do {
                try await transformation(error)
                let record = ErrorRecord(
                    error: error,
                    severity: .warning,
                    context: context,
                    timestamp: Date(),
                    resolution: .recovered
                )
                addToHistory(record)
            } catch {
                throw error
            }
            
        case .propagate:
            let record = ErrorRecord(
                error: error,
                severity: .error,
                context: context,
                timestamp: Date(),
                resolution: .propagated
            )
            addToHistory(record)
            throw error
        }
    }
    
    // MARK: - Error Presentation
    
    /// Show warning alert
    private func showWarning(_ record: ErrorRecord) {
        let alert = NSAlert()
        alert.messageText = "Warning"
        alert.informativeText = buildErrorMessage(for: record)
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    /// Show error alert
    private func showError(_ record: ErrorRecord) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = buildErrorMessage(for: record)
        alert.alertStyle = .critical
        
        // Add copy button for error details
        alert.addButton(withTitle: "Copy Details")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(buildErrorDetails(for: record), forType: .string)
        }
    }
    
    /// Build user-facing error message
    private func buildErrorMessage(for record: ErrorRecord) -> String {
        var message = record.error.localizedDescription
        
        // Add context if available
        if let recoverySuggestion = (record.error as NSError).localizedRecoverySuggestion {
            message += "\n\n\(recoverySuggestion)"
        }
        
        return message
    }
    
    /// Build detailed error information
    private func buildErrorDetails(for record: ErrorRecord) -> String {
        var details = """
            Error Details:
            -------------
            Timestamp: \(formatTimestamp(record.timestamp))
            Severity: \(record.severity)
            Operation: \(record.context.operationName)
            Location: \(record.context.file):\(record.context.line)
            Function: \(record.context.function)
            Error: \(record.error)
            Resolution: \(record.resolution)
            
            """
        
        // Add error chain if available
        if let nsError = record.error as NSError {
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                details += "\nUnderlying Error: \(underlyingError)"
            }
        }
        
        // Add user info
        if !record.context.userInfo.isEmpty {
            details += "\nUser Info:\n"
            for (key, value) in record.context.userInfo {
                details += "  \(key): \(value)\n"
            }
        }
        
        return details
    }
    
    // MARK: - Logging
    
    /// Log error to system
    private func logError(_ record: ErrorRecord) {
        let message = """
            [\(record.severity)] \(record.context.operationName) failed:
            Error: \(record.error)
            Location: \(record.context.file):\(record.context.line)
            Function: \(record.context.function)
            Resolution: \(record.resolution)
            """
        
        os_log(.error, "%{public}@", message)
    }
    
    // MARK: - History Management
    
    /// Add error record to history
    private func addToHistory(_ record: ErrorRecord) {
        errorHistory.insert(record, at: 0)
        if errorHistory.count > maxHistoryItems {
            errorHistory.removeLast()
        }
    }
    
    /// Get error history
    func getErrorHistory(severity: Severity? = nil) -> [ErrorRecord] {
        if let severity = severity {
            return errorHistory.filter { $0.severity >= severity }
        }
        return errorHistory
    }
    
    /// Clear error history
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Helpers
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}