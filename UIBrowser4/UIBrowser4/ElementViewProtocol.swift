import Cocoa

/// Protocol defining common functionality for all element viewing interfaces
@MainActor
protocol ElementViewProtocol: AnyObject {
    // MARK: - Properties
    
    /// Access to shared singleton instance
    static var sharedInstance: Self! { get }
    
    /// Path control manager
    var elementPathControlManager: ElementPathControlManager { get }
    
    /// Flag indicating manual selection
    var isManualSelection: Bool { get set }
    
    /// Flag indicating if focus tracking is enabled
    var isFocusTrackingEnabled: Bool { get set }
    
    /// Highlight current element
    func highlightCurrentElement()
    
    // MARK: - Methods
    
    /// Updates the view for a new target
    func updateView() async throws
    
    /// Shows the current view state
    func showView() async throws
    
    /// Clears the view
    func clearView()
    
    /// Handles element selection
    func selectElement(_ sender: NSMenuItem) async throws
    
    // MARK: - Path Control
    
    /// The path control for this view
    var pathControl: NSPathControl { get }
    
    /// Updates target selection in path control
    func updateTargetSelection()
    
    /// Displays current path in path control
    func displayPathControl()
    
    /// Clears path control
    func clearPathControl()
    
    // MARK: - Error Handling
    
    /// Handle view-specific errors
    func handleError(_ error: Error)
}

// MARK: - Default Implementations

extension ElementViewProtocol {
    func handleError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error in Element View"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}