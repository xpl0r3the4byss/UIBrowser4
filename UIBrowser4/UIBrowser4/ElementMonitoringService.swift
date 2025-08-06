import Cocoa
import Combine

/// Service for monitoring accessibility element changes
@MainActor
class ElementMonitoringService {
    // MARK: - Types
    
    /// Monitored attribute changes
    struct AttributeChange {
        let attribute: String
        let oldValue: Any?
        let newValue: Any?
        let timestamp: Date
    }
    
    /// Monitored notification
    struct ElementNotification {
        let name: String
        let element: AccessibleElement
        let info: [String: Any]?
        let timestamp: Date
    }
    
    /// Monitoring configuration
    struct MonitorConfig {
        var attributes: Set<String> = []
        var notifications: Set<String> = []
        var includeChildren: Bool = false
        var updateInterval: TimeInterval = 1.0
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementMonitoringService()
    
    /// Currently monitored element
    private var monitoredElement: AccessibleElement?
    
    /// Current configuration
    private var config = MonitorConfig()
    
    /// Monitoring task
    private var monitoringTask: Task<Void, Never>?
    
    /// Publishers
    let attributeChangesPublisher = PassthroughSubject<AttributeChange, Never>()
    let notificationsPublisher = PassthroughSubject<ElementNotification, Never>()
    let monitoringStatePublisher = CurrentValueSubject<Bool, Never>(false)
    
    // MARK: - Monitoring Control
    
    /// Start monitoring element
    func startMonitoring(_ element: AccessibleElement, config: MonitorConfig) {
        // Stop existing monitoring
        stopMonitoring()
        
        // Update state
        self.monitoredElement = element
        self.config = config
        
        // Start monitoring task
        monitoringTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Track previous values
            var previousValues: [String: Any] = [:]
            
            // Setup notification observers
            var notificationTasks: [Task<Void, Never>] = []
            for notification in config.notifications {
                let task = Task {
                    for await event in element.observeNotification(notification) {
                        await self.handleNotification(notification, for: element, info: event.userInfo)
                    }
                }
                notificationTasks.append(task)
            }
            
            // Monitor attributes
            while !Task.isCancelled {
                do {
                    // Check attributes
                    for attribute in config.attributes {
                        let value = await element.value(forAttribute: attribute)
                        
                        // Check for changes
                        if let previousValue = previousValues[attribute],
                           !isEqual(value, previousValue) {
                            let change = AttributeChange(
                                attribute: attribute,
                                oldValue: previousValue,
                                newValue: value,
                                timestamp: Date()
                            )
                            attributeChangesPublisher.send(change)
                        }
                        
                        previousValues[attribute] = value
                    }
                    
                    // Check children if enabled
                    if config.includeChildren {
                        await monitorChildren(of: element)
                    }
                    
                    // Wait for next update
                    try await Task.sleep(nanoseconds: UInt64(config.updateInterval * 1_000_000_000))
                } catch {
                    // Ignore sleep errors from cancellation
                    if !error.isCancellationError {
                        print("Monitoring error: \(error)")
                    }
                }
            }
            
            // Cancel notification observers
            for task in notificationTasks {
                task.cancel()
            }
        }
        
        monitoringStatePublisher.send(true)
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        monitoredElement = nil
        monitoringStatePublisher.send(false)
    }
    
    // MARK: - Event Handling
    
    /// Handle notification
    private func handleNotification(_ name: String, for element: AccessibleElement, info: [String: Any]?) {
        let notification = ElementNotification(
            name: name,
            element: element,
            info: info,
            timestamp: Date()
        )
        notificationsPublisher.send(notification)
        
        // Highlight element if it's the focused element
        if name == "AXFocusedUIElementChanged" {
            Task {
                await ElementHighlightService.shared.highlightElement(element)
            }
        }
    }
    
    /// Monitor children recursively
    private func monitorChildren(of element: AccessibleElement) async {
        guard let children = await element.children else { return }
        
        for child in children {
            // Check attributes
            for attribute in config.attributes {
                if let value = await child.value(forAttribute: attribute) {
                    // Just checking for existence is enough to trigger notifications
                    _ = value
                }
            }
            
            // Recurse if needed
            if config.includeChildren {
                await monitorChildren(of: child)
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Compare values for equality
    private func isEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        switch (value1, value2) {
        case (nil, nil):
            return true
        case let (v1 as NSObject, v2 as NSObject):
            return v1.isEqual(v2)
        case let (v1 as [Any], v2 as [Any]):
            return (v1 as NSArray).isEqual(v2 as NSArray)
        case let (v1 as [String: Any], v2 as [String: Any]):
            return (v1 as NSDictionary).isEqual(to: v2)
        default:
            return false
        }
    }
}

// MARK: - Error Extensions

extension Error {
    var isCancellationError: Bool {
        let nsError = self as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}