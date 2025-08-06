import Cocoa

/// Monitors process state and UI changes
@MainActor
final class ProcessMonitor {
    // MARK: - Types
    
    /// Process state change
    struct ProcessChange {
        let pid: pid_t
        let type: ChangeType
        let timestamp: Date
        
        enum ChangeType {
            case launched
            case terminated
            case windowCreated
            case windowDestroyed
            case focusChanged
            case interfaceChanged
        }
    }
    
    /// Monitor configuration
    struct Config {
        /// Monitoring interval
        var pollInterval: TimeInterval = 0.5
        
        /// Window creation delay
        var windowDelay: TimeInterval = 0.1
        
        /// Interface change coalescing
        var changeCoalescing: TimeInterval = 0.1
        
        /// Focus change delay
        var focusDelay: TimeInterval = 0.05
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ProcessMonitor()
    
    /// Current configuration
    private var config: Config = Config()
    
    /// Monitored processes
    private var monitoredProcesses: Set<pid_t> = []
    
    /// Process observations
    private var observations: [pid_t: Task<Void, Never>] = [:]
    
    /// Window cache
    private var windowCache: [pid_t: Set<CGWindowID>] = [:]
    
    /// Last change timestamps
    private var lastChanges: [pid_t: [ProcessChange.ChangeType: Date]] = [:]
    
    /// Publishers
    let processChangePublisher = PassthroughSubject<ProcessChange, Never>()
    
    // MARK: - Process Monitoring
    
    /// Start monitoring process
    func startMonitoring(_ pid: pid_t) {
        guard !monitoredProcesses.contains(pid) else { return }
        
        // Add to monitored set
        monitoredProcesses.insert(pid)
        
        // Create observation task
        observations[pid] = Task { [weak self] in
            await self?.observeProcess(pid)
        }
        
        // Cache initial windows
        updateWindowCache(for: pid)
    }
    
    /// Stop monitoring process
    func stopMonitoring(_ pid: pid_t) {
        // Cancel observation
        observations[pid]?.cancel()
        observations[pid] = nil
        
        // Remove from monitoring
        monitoredProcesses.remove(pid)
        windowCache[pid] = nil
        lastChanges[pid] = nil
    }
    
    /// Stop all monitoring
    func stopAllMonitoring() {
        for pid in monitoredProcesses {
            stopMonitoring(pid)
        }
    }
    
    // MARK: - Process Observation
    
    private func observeProcess(_ pid: pid_t) async {
        // Create AX observer
        guard let observer = try? AXObserver(processID: pid) else {
            return
        }
        
        // Setup notifications
        setupNotifications(observer, for: pid)
        
        while !Task.isCancelled {
            // Check process state
            guard processExists(pid) else {
                notifyChange(.terminated, for: pid)
                break
            }
            
            // Check windows
            checkWindows(for: pid)
            
            // Check interface changes
            checkInterfaceChanges(for: pid)
            
            // Wait for next check
            try? await Task.sleep(nanoseconds: UInt64(config.pollInterval * 1_000_000_000))
        }
        
        // Cleanup
        stopMonitoring(pid)
    }
    
    private func setupNotifications(_ observer: AXObserver, for pid: pid_t) {
        // Window notifications
        addNotification(observer, pid, "AXWindowCreated") { [weak self] in
            self?.handleWindowCreation(for: pid)
        }
        
        addNotification(observer, pid, "AXWindowDestroyed") { [weak self] in
            self?.handleWindowDestruction(for: pid)
        }
        
        // Focus notifications
        addNotification(observer, pid, "AXFocusedWindowChanged") { [weak self] in
            self?.handleFocusChange(for: pid)
        }
        
        addNotification(observer, pid, "AXFocusedUIElementChanged") { [weak self] in
            self?.handleFocusChange(for: pid)
        }
        
        // Interface notifications
        addNotification(observer, pid, "AXCreated") { [weak self] in
            self?.handleInterfaceChange(for: pid)
        }
        
        addNotification(observer, pid, "AXDestroyed") { [weak self] in
            self?.handleInterfaceChange(for: pid)
        }
        
        addNotification(observer, pid, "AXMoved") { [weak self] in
            self?.handleInterfaceChange(for: pid)
        }
        
        addNotification(observer, pid, "AXResized") { [weak self] in
            self?.handleInterfaceChange(for: pid)
        }
    }
    
    private func addNotification(
        _ observer: AXObserver,
        _ pid: pid_t,
        _ notification: String,
        handler: @escaping () -> Void
    ) {
        var callback: AXObserverCallback = { _, _, _, _ in
            Task { @MainActor in
                handler()
            }
        }
        
        AXObserverAddNotification(
            observer,
            AXUIElementCreateApplication(pid),
            notification as CFString,
            &callback
        )
    }
    
    // MARK: - Window Management
    
    private func checkWindows(for pid: pid_t) {
        let currentWindows = getWindows(for: pid)
        let cachedWindows = windowCache[pid] ?? Set()
        
        // Check for new windows
        let newWindows = currentWindows.subtracting(cachedWindows)
        if !newWindows.isEmpty {
            handleWindowCreation(for: pid)
        }
        
        // Check for destroyed windows
        let destroyedWindows = cachedWindows.subtracting(currentWindows)
        if !destroyedWindows.isEmpty {
            handleWindowDestruction(for: pid)
        }
        
        // Update cache
        windowCache[pid] = currentWindows
    }
    
    private func getWindows(for pid: pid_t) -> Set<CGWindowID> {
        var windows = Set<CGWindowID>()
        
        if let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] {
            for window in windowList {
                if let ownerPID = window[kCGWindowOwnerPID] as? pid_t,
                   ownerPID == pid,
                   let windowID = window[kCGWindowNumber] as? CGWindowID {
                    windows.insert(windowID)
                }
            }
        }
        
        return windows
    }
    
    // MARK: - Change Handlers
    
    private func handleWindowCreation(for pid: pid_t) {
        guard shouldNotifyChange(.windowCreated, for: pid) else { return }
        notifyChange(.windowCreated, for: pid)
        updateWindowCache(for: pid)
    }
    
    private func handleWindowDestruction(for pid: pid_t) {
        guard shouldNotifyChange(.windowDestroyed, for: pid) else { return }
        notifyChange(.windowDestroyed, for: pid)
        updateWindowCache(for: pid)
    }
    
    private func handleFocusChange(for pid: pid_t) {
        guard shouldNotifyChange(.focusChanged, for: pid) else { return }
        notifyChange(.focusChanged, for: pid)
    }
    
    private func handleInterfaceChange(for pid: pid_t) {
        guard shouldNotifyChange(.interfaceChanged, for: pid) else { return }
        notifyChange(.interfaceChanged, for: pid)
    }
    
    // MARK: - Change Management
    
    private func shouldNotifyChange(_ type: ProcessChange.ChangeType, for pid: pid_t) -> Bool {
        let now = Date()
        let changes = lastChanges[pid] ?? [:]
        
        if let lastChange = changes[type] {
            let interval: TimeInterval
            
            switch type {
            case .windowCreated, .windowDestroyed:
                interval = config.windowDelay
            case .focusChanged:
                interval = config.focusDelay
            case .interfaceChanged:
                interval = config.changeCoalescing
            default:
                interval = 0
            }
            
            guard now.timeIntervalSince(lastChange) >= interval else {
                return false
            }
        }
        
        return true
    }
    
    private func notifyChange(_ type: ProcessChange.ChangeType, for pid: pid_t) {
        // Update timestamp
        var changes = lastChanges[pid] ?? [:]
        changes[type] = Date()
        lastChanges[pid] = changes
        
        // Create change
        let change = ProcessChange(
            pid: pid,
            type: type,
            timestamp: Date()
        )
        
        // Notify observers
        processChangePublisher.send(change)
    }
    
    // MARK: - Helpers
    
    private func processExists(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }
    
    private func updateWindowCache(for pid: pid_t) {
        windowCache[pid] = getWindows(for: pid)
    }
}