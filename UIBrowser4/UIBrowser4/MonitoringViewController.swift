import Cocoa
import Combine

/// View controller for element monitoring interface
class MonitoringViewController: NSViewController {
    // MARK: - Properties
    
    /// Shared instance
    static private(set) var sharedInstance: MonitoringViewController!
    
    /// Current element
    private var currentElement: AccessibleElement?
    
    /// Monitoring configuration
    private var config = ElementMonitoringService.MonitorConfig()
    
    /// Event history
    private var attributeChanges: [ElementMonitoringService.AttributeChange] = []
    private var notifications: [ElementMonitoringService.ElementNotification] = []
    
    /// Max history items
    private let maxHistoryItems = 1000
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Outlets
    
    @IBOutlet weak var attributesTable: NSTableView!
    @IBOutlet weak var notificationsTable: NSTableView!
    @IBOutlet weak var startStopButton: NSButton!
    @IBOutlet weak var attributeSelector: NSPopUpButton!
    @IBOutlet weak var notificationSelector: NSPopUpButton!
    @IBOutlet weak var includeChildrenCheckbox: NSButton!
    @IBOutlet weak var updateIntervalSlider: NSSlider!
    @IBOutlet weak var updateIntervalLabel: NSTextField!
    @IBOutlet weak var clearButton: NSButton!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MonitoringViewController.sharedInstance = self
        setupUI()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure tables
        attributesTable.delegate = self
        attributesTable.dataSource = self
        notificationsTable.delegate = self
        notificationsTable.dataSource = self
        
        // Configure update interval
        updateIntervalLabel.stringValue = String(format: "%.1f s", config.updateInterval)
        updateIntervalSlider.doubleValue = config.updateInterval
        
        // Initial state
        startStopButton.title = "Start Monitoring"
        clearButton.isEnabled = false
    }
    
    private func setupObservers() {
        // Observe current element
        ElementDataModel.statePublisher
            .compactMap(\\.currentElement)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] element in
                self?.updateElement(element)
            }
            .store(in: &cancellables)
        
        // Observe monitoring state
        ElementMonitoringService.shared.monitoringStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isMonitoring in
                self?.startStopButton.title = isMonitoring ? "Stop Monitoring" : "Start Monitoring"
                self?.updateControls()
            }
            .store(in: &cancellables)
        
        // Observe attribute changes
        ElementMonitoringService.shared.attributeChangesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.handleAttributeChange(change)
            }
            .store(in: &cancellables)
        
        // Observe notifications
        ElementMonitoringService.shared.notificationsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleNotification(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @IBAction func toggleMonitoring(_ sender: Any) {
        if ElementMonitoringService.shared.monitoringStatePublisher.value {
            ElementMonitoringService.shared.stopMonitoring()
        } else if let element = currentElement {
            ElementMonitoringService.shared.startMonitoring(element, config: config)
        }
    }
    
    @IBAction func updateIntervalChanged(_ sender: NSSlider) {
        config.updateInterval = sender.doubleValue
        updateIntervalLabel.stringValue = String(format: "%.1f s", config.updateInterval)
    }
    
    @IBAction func includeChildrenChanged(_ sender: NSButton) {
        config.includeChildren = sender.state == .on
    }
    
    @IBAction func clearHistory(_ sender: Any) {
        attributeChanges.removeAll()
        notifications.removeAll()
        attributesTable.reloadData()
        notificationsTable.reloadData()
        clearButton.isEnabled = false
    }
    
    @IBAction func addAttribute(_ sender: NSPopUpButton) {
        guard let attribute = sender.selectedItem?.title else { return }
        config.attributes.insert(attribute)
        updateAttributeSelector()
    }
    
    @IBAction func addNotification(_ sender: NSPopUpButton) {
        guard let notification = sender.selectedItem?.title else { return }
        config.notifications.insert(notification)
        updateNotificationSelector()
    }
    
    // MARK: - Private Methods
    
    private func updateElement(_ element: AccessibleElement) {
        currentElement = element
        
        // Stop monitoring if active
        if ElementMonitoringService.shared.monitoringStatePublisher.value {
            ElementMonitoringService.shared.stopMonitoring()
        }
        
        // Update available attributes and notifications
        Task {
            // Get available attributes
            attributeSelector.removeAllItems()
            if let attributes = await element.attributes {
                attributeSelector.addItems(withTitles: attributes)
            }
            
            // Get available notifications
            notificationSelector.removeAllItems()
            if let notifications = await element.notifications {
                notificationSelector.addItems(withTitles: notifications)
            }
            
            updateControls()
        }
    }
    
    private func updateControls() {
        let isMonitoring = ElementMonitoringService.shared.monitoringStatePublisher.value
        
        attributeSelector.isEnabled = !isMonitoring
        notificationSelector.isEnabled = !isMonitoring
        includeChildrenCheckbox.isEnabled = !isMonitoring
        updateIntervalSlider.isEnabled = !isMonitoring
        startStopButton.isEnabled = currentElement != nil
    }
    
    private func updateAttributeSelector() {
        // Remove selected attributes
        attributeSelector.removeAllItems()
        if let element = currentElement,
           let attributes = try? await element.attributes {
            let available = Set(attributes).subtracting(config.attributes)
            attributeSelector.addItems(withTitles: Array(available))
        }
    }
    
    private func updateNotificationSelector() {
        // Remove selected notifications
        notificationSelector.removeAllItems()
        if let element = currentElement,
           let notifications = try? await element.notifications {
            let available = Set(notifications).subtracting(config.notifications)
            notificationSelector.addItems(withTitles: Array(available))
        }
    }
    
    private func handleAttributeChange(_ change: ElementMonitoringService.AttributeChange) {
        attributeChanges.insert(change, at: 0)
        if attributeChanges.count > maxHistoryItems {
            attributeChanges.removeLast()
        }
        attributesTable.reloadData()
        clearButton.isEnabled = true
    }
    
    private func handleNotification(_ notification: ElementMonitoringService.ElementNotification) {
        notifications.insert(notification, at: 0)
        if notifications.count > maxHistoryItems {
            notifications.removeLast()
        }
        notificationsTable.reloadData()
        clearButton.isEnabled = true
    }
}

// MARK: - NSTableViewDataSource

extension MonitoringViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == attributesTable {
            return attributeChanges.count
        } else {
            return notifications.count
        }
    }
}

// MARK: - NSTableViewDelegate

extension MonitoringViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
        
        if tableView == attributesTable {
            let change = attributeChanges[row]
            switch tableColumn?.identifier.rawValue {
            case "timestamp":
                cellView?.textField?.stringValue = formatTimestamp(change.timestamp)
            case "attribute":
                cellView?.textField?.stringValue = change.attribute
            case "oldValue":
                cellView?.textField?.stringValue = formatValue(change.oldValue)
            case "newValue":
                cellView?.textField?.stringValue = formatValue(change.newValue)
            default:
                break
            }
        } else {
            let notification = notifications[row]
            switch tableColumn?.identifier.rawValue {
            case "timestamp":
                cellView?.textField?.stringValue = formatTimestamp(notification.timestamp)
            case "notification":
                cellView?.textField?.stringValue = notification.name
            case "element":
                cellView?.textField?.stringValue = notification.element.description
            case "info":
                cellView?.textField?.stringValue = formatInfo(notification.info)
            default:
                break
            }
        }
        
        return cellView
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "nil" }
        return String(describing: value)
    }
    
    private func formatInfo(_ info: [String: Any]?) -> String {
        guard let info = info else { return "" }
        return info.map { "\($0): \($1)" }.joined(separator: ", ")
    }
}