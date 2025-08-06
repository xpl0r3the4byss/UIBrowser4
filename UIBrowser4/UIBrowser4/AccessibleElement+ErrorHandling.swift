import Cocoa

/// Error handling extensions for AccessibleElement
extension AccessibleElement {
    // MARK: - Error Context
    
    /// Create error context for operation
    func createErrorContext(
        operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        userInfo: [String: Any] = [:]
    ) -> ErrorHandlingSystem.ErrorContext {
        ErrorHandlingSystem.ErrorContext(
            file: file,
            function: function,
            line: line,
            timestamp: Date(),
            operationName: operation,
            userInfo: userInfo
        )
    }
    
    // MARK: - Protected Operations
    
    /// Perform accessibility operation with error handling
    func performProtectedOperation<T>(
        _ operation: String,
        severity: ErrorHandlingSystem.Severity = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        action: () async throws -> T
    ) async throws -> T {
        do {
            return try await action()
        } catch {
            // Create error context
            let context = createErrorContext(
                operation: operation,
                file: file,
                function: function,
                line: line,
                userInfo: [
                    "element": description,
                    "pid": await pid(),
                    "role": AXRole ?? "unknown",
                    "title": AXTitle ?? ""
                ]
            )
            
            // Handle error
            try await ErrorHandlingSystem.shared.handleError(
                error,
                severity: severity,
                context: context
            )
            
            throw error
        }
    }
    
    // MARK: - Attribute Access
    
    /// Get attribute value with error handling
    func protectedValue(
        forAttribute attribute: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async -> Any? {
        do {
            return try await performProtectedOperation(
                "Get Attribute '\(attribute)'",
                severity: .warning
            ) {
                try await self.value(forAttribute: attribute)
            }
        } catch {
            return nil
        }
    }
    
    /// Set attribute value with error handling
    func protectedSetValue(
        _ value: Any,
        forAttribute attribute: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async throws {
        try await performProtectedOperation(
            "Set Attribute '\(attribute)'",
            severity: .error
        ) {
            try await self.setValue(value, forAttribute: attribute)
        }
    }
    
    // MARK: - Action Execution
    
    /// Perform action with error handling
    func protectedPerformAction(
        _ action: String,
        value: Any? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async throws {
        try await performProtectedOperation(
            "Perform Action '\(action)'",
            severity: .error
        ) {
            try await self.performAction(action, value: value)
        }
    }
    
    // MARK: - Notification Observation
    
    /// Observe notification with error handling
    func protectedObserveNotification(
        _ notification: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> AsyncStream<NotificationEvent> {
        return AsyncStream { continuation in
            Task {
                do {
                    for try await event in observeNotification(notification) {
                        continuation.yield(event)
                    }
                } catch {
                    // Create error context
                    let context = createErrorContext(
                        operation: "Observe Notification '\(notification)'",
                        file: file,
                        function: function,
                        line: line,
                        userInfo: [
                            "element": description,
                            "notification": notification
                        ]
                    )
                    
                    // Handle error
                    try? await ErrorHandlingSystem.shared.handleError(
                        error,
                        severity: .warning,
                        context: context
                    )
                    
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Recovery Strategies
    
    /// Register common error recovery strategies
    func registerCommonStrategies() {
        let errorSystem = ErrorHandlingSystem.shared
        
        // Retry strategy for transient errors
        errorSystem.registerStrategy(
            .retry(maxAttempts: 3),
            for: "Get Attribute '*'"
        )
        
        // Recovery strategy for destroyed elements
        errorSystem.registerStrategy(
            .recover { [weak self] error in
                if error is AccessibilityError {
                    self?.isDestroyed = true
                }
            },
            for: "Perform Action '*'"
        )
        
        // Fallback strategy for notification observation
        errorSystem.registerStrategy(
            .fallback {
                // Stop observation and cleanup
            },
            for: "Observe Notification '*'"
        )
    }
}