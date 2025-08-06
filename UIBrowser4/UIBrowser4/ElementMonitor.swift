import Cocoa
import Combine

/// Monitors accessibility elements for changes and interactions
@MainActor
final class ElementMonitor {
    // MARK: - Types
    
    /// Monitored element change
    struct ElementChange: Equatable {
        let element: AccessibleElement
        let type: ChangeType
        let timestamp: Date
        let info: [String: Any]
        
        enum ChangeType: Equatable {
            case created
            case destroyed
            case modified(attribute: String)
            case focused
            case selected
            case childrenChanged
            case moved
            case resized
            case hidden
            case shown
            
            static func == (lhs: ChangeType, rhs: ChangeType) -> Bool {
                switch (lhs, rhs) {
                case (.created, .created),
                     (.destroyed, .destroyed),
                     (.focused, .focused),
                     (.selected, .selected),
                     (.childrenChanged, .childrenChanged),
                     (.moved, .moved),
                     (.resized, .resized),
                     (.hidden, .hidden),
                     (.shown, .shown):
                    return true
                case (.modified(let a1), .modified(let a2)):
                    return a1 == a2
                default:
                    return false
                }
            }
        }
    }
    
    /// Monitor configuration
    struct Config {
        /// Monitor children
        var includeChildren: Bool = true
        
        /// Monitor descendants
        var includeDescendants: Bool = false
        
        /// Update interval
        var updateInterval: TimeInterval = 0.5
        
        /// Change coalescing
        var changeCoalescing: TimeInterval = 0.1
        
        /// Highlighting configuration
        var highlightChanges: Bool = true
        var highlightDuration: TimeInterval = 1.0
        var highlightStyle: ElementHighlightWindow.Style = .standard
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementMonitor()
    
    /// Current configuration
    private(set) var config: Config
    
    /// Monitored elements
    private var monitoredElements: [AccessibleElement: Task<Void, Never>] = [:]
    
    /// Change timestamps
    private var changeTimestamps: [AccessibleElement: [ElementChange.ChangeType: Date]] = [:]
    
    /// Highlight windows
    private var highlightWindows: [AccessibleElement: ElementHighlightWindow] = [:]
    
    /// Publishers
    let elementChangePublisher = PassthroughSubject<ElementChange, Never>()
    let monitoringStatePublisher = CurrentValueSubject<Bool, Never>(false)
    
    // MARK: - Initialization
    
    private init(config: Config = Config()) {
        self.config = config
    }
    
    // MARK: - Monitoring Control
    
    /// Start monitoring element
    func startMonitoring(_ element: AccessibleElement) {
        guard monitoredElements[element] == nil else { return }
        
        // Create monitoring task
        let task = Task { [weak self] in
            await self?.monitorElement(element)
        }
        
        monitoredElements[element] = task
        monitoringStatePublisher.send(true)
    }
    
    /// Stop monitoring element
    func stopMonitoring(_ element: AccessibleElement) {
        // Cancel task
        monitoredElements[element]?.cancel()
        monitoredElements[element] = nil
        
        // Remove timestamps
        changeTimestamps[element] = nil
        
        // Remove highlight
        highlightWindows[element]?.hideHighlight()
        highlightWindows[element] = nil
        
        if monitoredElements.isEmpty {
            monitoringStatePublisher.send(false)
        }
    }
    
    /// Stop all monitoring
    func stopAllMonitoring() {
        for element in monitoredElements.keys {
            stopMonitoring(element)
        }
    }
    
    /// Update configuration
    func updateConfig(_ newConfig: Config) {
        config = newConfig
        
        // Update highlight windows
        for window in highlightWindows.values {
            window.updateStyle(newConfig.highlightStyle)
        }
    }
    
    // MARK: - Element Monitoring
    
    private func monitorElement(_ element: AccessibleElement) async {
        // Setup notifications
        let notifications = [
            "AXCreated",
            "AXDestroyed",
            "AXFocused",
            "AXSelectedChildrenChanged",
            "AXMoved",
            "AXResized",
            "AXHidden",
            "AXShown"
        ]
        
        // Create notification tasks
        var notificationTasks: [Task<Void, Never>] = []
        
        for notification in notifications {
            let task = Task { [weak self] in
                for await event in element.observeNotification(notification) {
                    await self?.handleNotification(notification, for: element, info: event.userInfo)
                }
            }
            notificationTasks.append(task)
        }
        
        // Monitor attributes
        while !Task.isCancelled {
            do {
                // Check attributes
                if let attributes = try? await element.allAttributes() {
                    for (key, value) in attributes {
                        if let oldValue = try? await element.value(forAttribute: key),
                           !isEqual(value, oldValue) {
                            await handleChange(.modified(attribute: key), for: element)
                        }
                    }
                }
                
                // Check children if enabled
                if config.includeChildren {
                    await monitorChildren(of: element)
                }
                
                // Wait for next update
                try await Task.sleep(nanoseconds: UInt64(config.updateInterval * 1_000_000_000))
            } catch {
                // Handle errors
                if error is CancellationError {
                    break
                }
                print("Error monitoring element: \(error)")
            }
        }
        
        // Cancel notification tasks
        for task in notificationTasks {
            task.cancel()
        }
    }
    
    private func monitorChildren(of element: AccessibleElement) async {
        guard let children = await element.children else { return }
        
        for child in children {
            // Monitor child if not already monitored
            if monitoredElements[child] == nil {
                startMonitoring(child)
            }
            
            // Monitor descendants if enabled
            if config.includeDescendants {
                await monitorChildren(of: child)
            }
        }
    }
    
    // MARK: - Change Handling
    
    private func handleNotification(
        _ notification: String,
        for element: AccessibleElement,
        info: [String: Any]?
    ) async {
        let type: ElementChange.ChangeType
        
        switch notification {
        case "AXCreated":
            type = .created
        case "AXDestroyed":
            type = .destroyed
        case "AXFocused":
            type = .focused
        case "AXSelectedChildrenChanged":
            type = .childrenChanged
        case "AXMoved":
            type = .moved
        case "AXResized":
            type = .resized
        case "AXHidden":
            type = .hidden
        case "AXShown":
            type = .shown
        default:
            return
        }
        
        await handleChange(type, for: element, info: info)
    }
    
    private func handleChange(
        _ type: ElementChange.ChangeType,
        for element: AccessibleElement,
        info: [String: Any]? = nil
    ) async {
        // Check coalescing
        if !shouldNotifyChange(type, for: element) {
            return
        }
        
        // Create change
        let change = ElementChange(
            element: element,
            type: type,
            timestamp: Date(),
            info: info ?? [:]
        )
        
        // Update timestamps
        var timestamps = changeTimestamps[element] ?? [:]
        timestamps[type] = change.timestamp
        changeTimestamps[element] = timestamps
        
        // Notify change
        elementChangePublisher.send(change)
        
        // Update highlight
        if config.highlightChanges {
            await highlightElement(element, for: type)
        }
    }
    
    private func shouldNotifyChange(
        _ type: ElementChange.ChangeType,
        for element: AccessibleElement
    ) -> Bool {
        let now = Date()
        
        if let timestamps = changeTimestamps[element],
           let lastChange = timestamps[type] {
            return now.timeIntervalSince(lastChange) >= config.changeCoalescing
        }
        
        return true
    }
    
    // MARK: - Highlighting
    
    private func highlightElement(
        _ element: AccessibleElement,
        for changeType: ElementChange.ChangeType
    ) async {
        // Get element frame
        guard let position = element.AXPosition as? NSPoint,
              let size = element.AXSize as? NSSize else {
            return
        }
        
        let frame = NSRect(origin: position, size: size)
        
        // Get or create highlight window
        let window = highlightWindows[element] ?? ElementHighlightWindow(style: config.highlightStyle)
        highlightWindows[element] = window
        
        // Show highlight
        window.showHighlight(for: frame)
        
        // Hide after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(config.highlightDuration * 1_000_000_000))
            window.hideHighlight()
        }
    }
    
    // MARK: - Helpers
    
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