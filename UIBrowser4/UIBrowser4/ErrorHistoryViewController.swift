import Cocoa
import Combine

/// View controller for displaying error history and monitoring
class ErrorHistoryViewController: NSViewController {
    // MARK: - Properties
    
    /// Shared instance
    static private(set) var sharedInstance: ErrorHistoryViewController!
    
    /// Displayed errors
    private var displayedErrors: [ErrorHandlingSystem.ErrorRecord] = []
    
    /// Filter settings
    private var selectedSeverity: ErrorHandlingSystem.Severity?
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var severityPopup: NSPopUpButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var detailsTextView: NSTextView!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ErrorHistoryViewController.sharedInstance = self
        setupUI()
        setupObservers()
        updateDisplayedErrors()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure table
        tableView.delegate = self
        tableView.dataSource = self
        
        // Configure severity filter
        severityPopup.removeAllItems()
        severityPopup.addItem(withTitle: "All Severities")
        severityPopup.addItem(withTitle: "Info and above")
        severityPopup.addItem(withTitle: "Warnings and above")
        severityPopup.addItem(withTitle: "Errors and above")
        severityPopup.addItem(withTitle: "Critical only")
        
        // Configure search
        searchField.delegate = self
        
        // Configure details
        detailsTextView.isEditable = false
        detailsTextView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    }
    
    private func setupObservers() {
        // Observe new errors
        ErrorHandlingSystem.shared.errorOccurredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] record in
                self?.handleNewError(record)
            }
            .store(in: &cancellables)
        
        // Observe critical errors
        ErrorHandlingSystem.shared.criticalErrorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] record in
                self?.handleCriticalError(record)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @IBAction func severityChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0:
            selectedSeverity = nil
        case 1:
            selectedSeverity = .info
        case 2:
            selectedSeverity = .warning
        case 3:
            selectedSeverity = .error
        case 4:
            selectedSeverity = .critical
        default:
            break
        }
        
        updateDisplayedErrors()
    }
    
    @IBAction func clearHistory(_ sender: Any) {
        ErrorHandlingSystem.shared.clearErrorHistory()
        updateDisplayedErrors()
    }
    
    @IBAction func copyDetails(_ sender: Any) {
        guard !detailsTextView.string.isEmpty else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(detailsTextView.string, forType: .string)
    }
    
    // MARK: - Error Handling
    
    private func handleNewError(_ record: ErrorHandlingSystem.ErrorRecord) {
        updateDisplayedErrors()
        
        // Auto-scroll to new error if visible
        if shouldDisplayError(record) {
            tableView.scrollRowToVisible(0)
        }
    }
    
    private func handleCriticalError(_ record: ErrorHandlingSystem.ErrorRecord) {
        // Highlight critical errors
        if let row = displayedErrors.firstIndex(where: { $0.id == record.id }) {
            let rowView = tableView.rowView(atRow: row, makeIfNecessary: false)
            rowView?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.2)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateDisplayedErrors() {
        let searchText = searchField.stringValue.lowercased()
        
        displayedErrors = ErrorHandlingSystem.shared.getErrorHistory(severity: selectedSeverity)
            .filter { record in
                if searchText.isEmpty { return true }
                
                // Search in error details
                let details = """
                    \(record.error.localizedDescription)
                    \(record.context.operationName)
                    \(record.context.function)
                    \(record.resolution)
                    """
                return details.lowercased().contains(searchText)
            }
        
        tableView.reloadData()
        clearButton.isEnabled = !displayedErrors.isEmpty
    }
    
    private func shouldDisplayError(_ record: ErrorHandlingSystem.ErrorRecord) -> Bool {
        if let severity = selectedSeverity, record.severity < severity {
            return false
        }
        
        let searchText = searchField.stringValue.lowercased()
        if !searchText.isEmpty {
            let details = """
                \(record.error.localizedDescription)
                \(record.context.operationName)
                \(record.context.function)
                \(record.resolution)
                """
            return details.lowercased().contains(searchText)
        }
        
        return true
    }
    
    private func updateErrorDetails(for record: ErrorHandlingSystem.ErrorRecord?) {
        if let record = record {
            let message = """
                Error Details
                ------------
                Timestamp: \(formatTimestamp(record.timestamp))
                Severity: \(record.severity)
                Operation: \(record.context.operationName)
                
                Error: \(record.error.localizedDescription)
                Resolution: \(record.resolution)
                
                Context
                -------
                File: \(record.context.file)
                Function: \(record.context.function)
                Line: \(record.context.line)
                Retry Count: \(record.context.retryCount)
                
                Stack Trace
                -----------
                \((record.error as NSError).callStackSymbols.joined(separator: "\n"))
                """
            
            detailsTextView.string = message
        } else {
            detailsTextView.string = ""
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

// MARK: - NSTableViewDataSource

extension ErrorHistoryViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedErrors.count
    }
}

// MARK: - NSTableViewDelegate

extension ErrorHistoryViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let record = displayedErrors[row]
        
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
        
        switch tableColumn?.identifier.rawValue {
        case "timestamp":
            cellView?.textField?.stringValue = formatTimestamp(record.timestamp)
        case "severity":
            cellView?.textField?.stringValue = "\(record.severity)"
        case "operation":
            cellView?.textField?.stringValue = record.context.operationName
        case "error":
            cellView?.textField?.stringValue = record.error.localizedDescription
        case "resolution":
            cellView?.textField?.stringValue = "\(record.resolution)"
        default:
            break
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0,
              tableView.selectedRow < displayedErrors.count else {
            updateErrorDetails(for: nil)
            return
        }
        
        let record = displayedErrors[tableView.selectedRow]
        updateErrorDetails(for: record)
    }
}

// MARK: - NSSearchFieldDelegate

extension ErrorHistoryViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateDisplayedErrors()
    }
}