import Cocoa

/// Manages target application selection and monitoring
@MainActor
final class TargetApplicationManager {
    // MARK: - Types
    
    /// Target application state
    enum TargetState {
        case none
        case systemWide
        case application(NSRunningApplication)
    }
    
    /// Target selection options
    struct SelectionOptions {
        var autoRefresh: Bool = true
        var highlightTarget: Bool = true
        var restorePosition: Bool = true
    }
    
    /// Target change notification
    struct TargetChange {
        let oldTarget: TargetState
        let newTarget: TargetState
        let timestamp: Date
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = TargetApplicationManager()
    
    /// Current target state
    private(set) var currentTarget: TargetState = .none {
        didSet {
            if oldValue != currentTarget {
                notifyTargetChange(from: oldValue, to: currentTarget)
            }
        }
    }
    
    /// Recent targets (excluding system-wide)
    private var recentTargets: [NSRunningApplication] = []
    
    /// Running applications snapshot
    private var runningApplications: [NSRunningApplication] = []
    
    /// Application monitoring task
    private var monitoringTask: Task<Void, Never>?
    
    /// Auto-refresh task
    private var refreshTask: Task<Void, Never>?
    
    /// Selection options
    var selectionOptions = SelectionOptions()
    
    /// Publishers
    let targetChangePublisher = PassthroughSubject<TargetChange, Never>()
    let applicationListPublisher = CurrentValueSubject<[NSRunningApplication], Never>([])
    
    // MARK: - Initialization
    
    private init() {
        setupApplicationMonitoring()
    }
    
    // MARK: - Target Management
    
    /// Select system-wide target
    func selectSystemWideTarget() async throws {
        // Stop any active monitoring
        stopTargetMonitoring()
        
        // Update state
        currentTarget = .systemWide
        
        // Create root element
        let systemElement = try await AccessibleElement.systemWide()
        ElementDataModel.sharedInstance.updateForNewTarget(systemElement)
        
        // Start monitoring if enabled
        if selectionOptions.autoRefresh {
            startTargetMonitoring()
        }
    }
    
    /// Select application target
    func selectApplicationTarget(_ application: NSRunningApplication) async throws {
        // Verify application is running
        guard application.isFinishedLaunching else {
            throw TargetError.applicationNotReady
        }
        
        // Stop any active monitoring
        stopTargetMonitoring()
        
        // Update state
        currentTarget = .application(application)
        
        // Add to recent targets
        updateRecentTargets(with: application)
        
        // Create root element
        let appElement = try await AccessibleElement.application(for: application)
        ElementDataModel.sharedInstance.updateForNewTarget(appElement)
        
        // Highlight if enabled
        if selectionOptions.highlightTarget {
            if let window = application.windows.first {
                await ElementHighlightService.shared.highlightElement(
                    try await AccessibleElement.window(for: window)
                )
            }
        }
        
        // Start monitoring if enabled
        if selectionOptions.autoRefresh {
            startTargetMonitoring()
        }
    }
    
    /// Clear current target
    func clearTarget() {
        stopTargetMonitoring()
        currentTarget = .none
        ElementDataModel.sharedInstance.clear()
    }
    
    /// Get recent targets
    func getRecentTargets(limit: Int = 5) -> [NSRunningApplication] {
        return Array(recentTargets.prefix(limit))
    }
    
    // MARK: - Application Monitoring
    
    /// Setup application monitoring
    private func setupApplicationMonitoring() {
        monitoringTask = Task { [weak self] in
            let workspace = NSWorkspace.shared
            
            // Observe application launches
            for await notification in workspace.notifications(named: NSWorkspace.didLaunchApplicationNotification) {
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    await self?.handleApplicationLaunch(app)
                }
            }
            
            // Observe application terminations
            for await notification in workspace.notifications(named: NSWorkspace.didTerminateApplicationNotification) {
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    await self?.handleApplicationTermination(app)
                }
            }
        }
        
        // Initial application list
        updateRunningApplications()
    }
    
    /// Handle application launch
    private func handleApplicationLaunch(_ application: NSRunningApplication) {
        runningApplications.append(application)
        applicationListPublisher.send(runningApplications)
        
        // Update current target if needed
        if case .application(let currentApp) = currentTarget,
           currentApp == application {
            // Refresh target
            refreshTarget()
        }
    }
    
    /// Handle application termination
    private func handleApplicationTermination(_ application: NSRunningApplication) {
        runningApplications.removeAll { $0 == application }
        applicationListPublisher.send(runningApplications)
        
        // Clear target if terminated
        if case .application(let currentApp) = currentTarget,
           currentApp == application {
            clearTarget()
        }
    }
    
    /// Update running applications list
    private func updateRunningApplications() {
        runningApplications = NSWorkspace.shared.runningApplications
        applicationListPublisher.send(runningApplications)
    }
    
    // MARK: - Target Monitoring
    
    /// Start target monitoring
    private func startTargetMonitoring() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                // Refresh target
                await self?.refreshTarget()
                
                // Wait for next refresh
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    /// Stop target monitoring
    private func stopTargetMonitoring() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    /// Refresh current target
    private func refreshTarget() async {
        switch currentTarget {
        case .none:
            break
            
        case .systemWide:
            do {
                let systemElement = try await AccessibleElement.systemWide()
                ElementDataModel.sharedInstance.updateForNewTarget(systemElement)
            } catch {
                handleRefreshError(error)
            }
            
        case .application(let application):
            guard application.isFinishedLaunching else { return }
            
            do {
                let appElement = try await AccessibleElement.application(for: application)
                ElementDataModel.sharedInstance.updateForNewTarget(appElement)
            } catch {
                handleRefreshError(error)
            }
        }
    }
    
    // MARK: - Recent Targets
    
    /// Update recent targets list
    private func updateRecentTargets(with application: NSRunningApplication) {
        // Remove existing entry
        recentTargets.removeAll { $0 == application }
        
        // Add to front
        recentTargets.insert(application, at: 0)
        
        // Trim list
        if recentTargets.count > 10 {
            recentTargets.removeLast()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleRefreshError(_ error: Error) {
        Task {
            // Create error context
            let context = ErrorHandlingSystem.ErrorContext(
                file: #file,
                function: #function,
                line: #line,
                timestamp: Date(),
                operationName: "Target Refresh",
                userInfo: [
                    "target": String(describing: currentTarget)
                ]
            )
            
            // Handle error
            try await ErrorHandlingSystem.shared.handleError(
                error,
                severity: .warning,
                context: context
            )
        }
    }
    
    private func notifyTargetChange(from oldTarget: TargetState, to newTarget: TargetState) {
        let change = TargetChange(
            oldTarget: oldTarget,
            newTarget: newTarget,
            timestamp: Date()
        )
        targetChangePublisher.send(change)
    }
}

// MARK: - Supporting Types

enum TargetError: LocalizedError {
    case applicationNotReady
    case applicationNotRunning
    case accessibilityDisabled
    
    var errorDescription: String? {
        switch self {
        case .applicationNotReady:
            return "Application is not ready for accessibility access"
        case .applicationNotRunning:
            return "Application is not running"
        case .accessibilityDisabled:
            return "Accessibility access is disabled"
        }
    }
}