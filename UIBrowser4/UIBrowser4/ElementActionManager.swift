import Cocoa

/// Manages accessibility element action execution and monitoring
@MainActor
class ElementActionManager {
    // MARK: - Types
    
    /// Represents an accessibility action
    struct Action: Hashable {
        let name: String
        let description: String
        let parameterDescription: String?
        let requiresValue: Bool
        
        static let standardActions: [Action] = [
            Action(name: "AXPress", description: "Press", parameterDescription: nil, requiresValue: false),
            Action(name: "AXIncrement", description: "Increment", parameterDescription: nil, requiresValue: false),
            Action(name: "AXDecrement", description: "Decrement", parameterDescription: nil, requiresValue: false),
            Action(name: "AXConfirm", description: "Confirm", parameterDescription: nil, requiresValue: false),
            Action(name: "AXCancel", description: "Cancel", parameterDescription: nil, requiresValue: false),
            Action(name: "AXShowMenu", description: "Show Menu", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowHour", description: "Show Hour", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowMinute", description: "Show Minute", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowSecond", description: "Show Second", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowAMPM", description: "Show AM/PM", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowDayOfWeek", description: "Show Day of Week", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowDayOfMonth", description: "Show Day of Month", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowMonth", description: "Show Month", parameterDescription: nil, requiresValue: false),
            Action(name: "AXPickerShowYear", description: "Show Year", parameterDescription: nil, requiresValue: false),
            Action(name: "AXRaise", description: "Raise", parameterDescription: nil, requiresValue: false),
            Action(name: "AXShowDefaultUIElement", description: "Show Default", parameterDescription: nil, requiresValue: false),
            Action(name: "AXScrollToVisible", description: "Scroll to Visible", parameterDescription: nil, requiresValue: false)
        ]
    }
    
    /// Result of action execution
    enum ActionResult {
        case success
        case failure(Error)
        case valueRequired(String)
        case unavailable
        case timeout
    }
    
    /// Action execution error
    enum ActionError: LocalizedError {
        case actionUnavailable(String)
        case invalidValue
        case timeout
        case executionFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .actionUnavailable(let action):
                return "Action '\(action)' is not available for this element"
            case .invalidValue:
                return "Invalid value provided for action"
            case .timeout:
                return "Action execution timed out"
            case .executionFailed(let error):
                return "Action execution failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementActionManager()
    
    /// Default timeout for actions
    var defaultTimeout: TimeInterval = 5.0
    
    /// Action completion handler
    private var completionHandler: ((ActionResult) -> Void)?
    
    // MARK: - Action Management
    
    /// Get available actions for element
    func availableActions(for element: AccessibleElement) async -> [Action] {
        var actions = [Action]()
        
        // Get standard actions
        for action in Action.standardActions {
            if await element.canPerformAction(action.name) {
                actions.append(action)
            }
        }
        
        // Get custom actions
        if let customActions = await element.customActions {
            for actionName in customActions {
                // Get action description if available
                let description = await element.actionDescription(for: actionName) ?? actionName
                let paramDesc = await element.actionParameterDescription(for: actionName)
                let requiresValue = await element.actionRequiresValue(actionName)
                
                let action = Action(
                    name: actionName,
                    description: description,
                    parameterDescription: paramDesc,
                    requiresValue: requiresValue
                )
                actions.append(action)
            }
        }
        
        return actions
    }
    
    /// Execute action on element
    func executeAction(_ action: Action, on element: AccessibleElement, value: Any? = nil) async throws -> ActionResult {
        // Verify action is available
        guard await element.canPerformAction(action.name) else {
            return .failure(ActionError.actionUnavailable(action.name))
        }
        
        // Check if value is required
        if action.requiresValue {
            guard let value = value else {
                return .valueRequired(action.parameterDescription ?? "Value required")
            }
        }
        
        // Execute with timeout
        return try await withTimeout(defaultTimeout) {
            do {
                try await element.performAction(action.name, value: value)
                return .success
            } catch {
                return .failure(ActionError.executionFailed(error))
            }
        }
    }
    
    /// Execute multiple actions in sequence
    func executeActions(_ actions: [(Action, Any?)], on element: AccessibleElement) async throws -> [ActionResult] {
        var results = [ActionResult]()
        
        for (action, value) in actions {
            let result = try await executeAction(action, on: element, value: value)
            results.append(result)
            
            // Stop on failure
            if case .failure = result {
                break
            }
        }
        
        return results
    }
    
    // MARK: - Helpers
    
    /// Execute with timeout
    private func withTimeout<T>(_ seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ActionError.timeout
            }
            
            // Add operation task
            group.addTask {
                return try await operation()
            }
            
            // Return first completed result
            return try await group.next() ?? { throw ActionError.timeout }()
        }
    }
    
    /// Format action result for display
    func formatResult(_ result: ActionResult) -> String {
        switch result {
        case .success:
            return "Action completed successfully"
        case .failure(let error):
            return "Action failed: \(error.localizedDescription)"
        case .valueRequired(let description):
            return "Value required: \(description)"
        case .unavailable:
            return "Action is not available"
        case .timeout:
            return "Action timed out"
        }
    }
}