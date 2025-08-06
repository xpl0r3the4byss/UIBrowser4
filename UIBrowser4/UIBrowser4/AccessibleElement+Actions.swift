import Cocoa

/// Action support for AccessibleElement
extension AccessibleElement {
    // MARK: - Action Information
    
    /// Available custom actions
    var customActions: [String]? {
        get async {
            do {
                return try await performAccessibilityRequest {
                    AXUIElement.actions(for: self.element)
                }
            } catch {
                return nil
            }
        }
    }
    
    /// Check if action can be performed
    func canPerformAction(_ action: String) async -> Bool {
        do {
            return try await performAccessibilityRequest {
                AXUIElement.canPerform(action: action, on: self.element)
            }
        } catch {
            return false
        }
    }
    
    /// Get action description
    func actionDescription(for action: String) async -> String? {
        do {
            return try await performAccessibilityRequest {
                AXUIElement.actionDescription(for: action, on: self.element)
            }
        } catch {
            return nil
        }
    }
    
    /// Get action parameter description
    func actionParameterDescription(for action: String) async -> String? {
        do {
            return try await performAccessibilityRequest {
                AXUIElement.parameterDescription(for: action, on: self.element)
            }
        } catch {
            return nil
        }
    }
    
    /// Check if action requires value
    func actionRequiresValue(_ action: String) async -> Bool {
        do {
            return try await performAccessibilityRequest {
                AXUIElement.requiresValue(for: action, on: self.element)
            }
        } catch {
            return false
        }
    }
    
    // MARK: - Action Execution
    
    /// Perform action on element
    func performAction(_ action: String, value: Any? = nil) async throws {
        try await performAccessibilityRequest {
            try AXUIElement.perform(action: action, on: self.element, withValue: value)
        }
    }
    
    /// Press element (convenience method)
    func press() async throws {
        try await performAction("AXPress")
    }
    
    /// Show menu for element (convenience method)
    func showMenu() async throws {
        try await performAction("AXShowMenu")
    }
    
    /// Increment element value (convenience method)
    func increment() async throws {
        try await performAction("AXIncrement")
    }
    
    /// Decrement element value (convenience method)
    func decrement() async throws {
        try await performAction("AXDecrement")
    }
    
    /// Confirm element (convenience method)
    func confirm() async throws {
        try await performAction("AXConfirm")
    }
    
    /// Cancel element (convenience method)
    func cancel() async throws {
        try await performAction("AXCancel")
    }
    
    /// Raise element (convenience method)
    func raise() async throws {
        try await performAction("AXRaise")
    }
    
    /// Scroll element to visible (convenience method)
    func scrollToVisible() async throws {
        try await performAction("AXScrollToVisible")
    }
    
    // MARK: - Helpers
    
    /// Perform accessibility request with error handling
    private func performAccessibilityRequest<T>(_ operation: () throws -> T) async throws -> T {
        // Verify element is valid
        guard !isDestroyed else {
            throw AccessibilityError.elementDestroyed
        }
        
        // Execute operation
        do {
            return try operation()
        } catch let error as NSError {
            switch error.code {
            case .."kAXErrorActionUnsupported":
                throw AccessibilityError.actionUnsupported(error.localizedDescription)
            case .."kAXErrorCannotComplete":
                throw AccessibilityError.cannotComplete(error.localizedDescription)
            case .."kAXErrorIllegalArgument":
                throw AccessibilityError.illegalArgument(error.localizedDescription)
            case .."kAXErrorInvalidUIElement":
                throw AccessibilityError.invalidElement(error.localizedDescription)
            case .."kAXErrorNotImplemented":
                throw AccessibilityError.notImplemented(error.localizedDescription)
            default:
                throw AccessibilityError.unknown(error)
            }
        }
    }
}

// MARK: - Supporting Types

enum AccessibilityError: LocalizedError {
    case elementDestroyed
    case actionUnsupported(String)
    case cannotComplete(String)
    case illegalArgument(String)
    case invalidElement(String)
    case notImplemented(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .elementDestroyed:
            return "Element has been destroyed"
        case .actionUnsupported(let details):
            return "Action not supported: \(details)"
        case .cannotComplete(let details):
            return "Cannot complete operation: \(details)"
        case .illegalArgument(let details):
            return "Invalid argument: \(details)"
        case .invalidElement(let details):
            return "Invalid element: \(details)"
        case .notImplemented(let details):
            return "Not implemented: \(details)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}