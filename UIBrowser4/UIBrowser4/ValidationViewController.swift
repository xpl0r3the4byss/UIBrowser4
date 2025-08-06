import Cocoa
import Combine

/// View controller for accessibility validation results
class ValidationViewController: NSViewController {
    // MARK: - Properties
    
    private var subscriptions = Set<AnyCancellable>()
    private var results: [AccessibilityValidator.ValidationResult] = []
    
    // MARK: - Outlets
    
    @IBOutlet weak var ruleTable: NSTableView!
    @IBOutlet weak var resultsTable: NSTableView!
    @IBOutlet weak var detailTextView: NSTextView!
    
    @IBOutlet weak var validateButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var exportButton: NSButton!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure tables
        ruleTable.delegate = self
        ruleTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.dataSource = self
        
        // Configure text view
        detailTextView.isEditable = false
        detailTextView.font = .systemFont(ofSize: NSFont.systemFontSize)
        
        // Load rules
        ruleTable.reloadData()
    }
    
    private func setupBindings() {
        // Handle validation results
        AccessibilityValidator.shared.resultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.updateResults(results)
            }
            .store(in: &subscriptions)
    }
    
    // MARK: - Actions
    
    @IBAction func validateButtonClicked(_ sender: Any) {
        Task {
            // Show progress
            validateButton.isEnabled = false
            progressIndicator.startAnimation(nil)
            
            // Run validation
            if let element = ElementDataModel.sharedInstance.currentElement {
                let results = await AccessibilityValidator.shared.validateElementTree(element)
                self.results = results
                resultsTable.reloadData()
                exportButton.isEnabled = !results.isEmpty
            }
            
            // Hide progress
            validateButton.isEnabled = true
            progressIndicator.stopAnimation(nil)
        }
    }
    
    @IBAction func exportResults(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv"]
        panel.nameFieldStringValue = "validation_results.csv"
        
        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK, let url = panel.url {
                self.exportResultsToCSV(url)
            }
        }
    }
    
    @IBAction func ruleCheckboxClicked(_ sender: NSButton) {
        guard let rule = AccessibilityValidator.RuleType(rawValue: sender.identifier?.rawValue ?? "") else {
            return
        }
        
        if sender.state == .on {
            AccessibilityValidator.shared.enableRule(rule)
        } else {
            AccessibilityValidator.shared.disableRule(rule)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateResults(_ results: [AccessibilityValidator.ValidationResult]) {
        self.results = results
        resultsTable.reloadData()
        exportButton.isEnabled = !results.isEmpty
        
        if let first = results.first {
            showResultDetails(first)
        }
    }
    
    private func showResultDetails(_ result: AccessibilityValidator.ValidationResult) {
        var details = """
            Validation Result
            
            Type: \(result.type.rawValue)
            Severity: \(result.severity.rawValue)
            
            Element:
            - Role: \(result.element.AXRole ?? "Unknown")
            - Title: \(result.element.AXTitle ?? "None")
            - Description: \(result.element.AXDescription ?? "None")
            
            Message:
            \(result.message)
            
            """
        
        if let suggestion = result.suggestion {
            details += """
            
            Suggestion:
            \(suggestion)
            """
        }
        
        detailTextView.string = details
    }
    
    private func exportResultsToCSV(_ url: URL) {
        var csv = "Type,Severity,Message,Suggestion,Element Role,Element Title\n"
        
        for result in results {
            let row = [
                result.type.rawValue,
                result.severity.rawValue,
                result.message,
                result.suggestion ?? "",
                result.element.AXRole ?? "",
                result.element.AXTitle ?? ""
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: ",")
            
            csv += row + "\n"
        }
        
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - NSTableViewDataSource

extension ValidationViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == ruleTable {
            return AccessibilityValidator.RuleType.allCases.count
        } else if tableView == resultsTable {
            return results.count
        }
        return 0
    }
}

// MARK: - NSTableViewDelegate

extension ValidationViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: self) as? NSTableCellView
        
        if tableView == ruleTable {
            let rule = AccessibilityValidator.RuleType.allCases[row]
            
            switch tableColumn?.identifier.rawValue {
            case "enabled":
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(ruleCheckboxClicked(_:)))
                checkbox.state = AccessibilityValidator.shared.activeRules.contains(rule) ? .on : .off
                checkbox.identifier = NSUserInterfaceItemIdentifier(rule.rawValue)
                return checkbox
                
            case "rule":
                cell?.textField?.stringValue = rule.rawValue
                
            default:
                break
            }
            
        } else if tableView == resultsTable {
            let result = results[row]
            
            switch tableColumn?.identifier.rawValue {
            case "severity":
                cell?.textField?.stringValue = result.severity.rawValue
                
            case "type":
                cell?.textField?.stringValue = result.type.rawValue
                
            case "message":
                cell?.textField?.stringValue = result.message
                
            default:
                break
            }
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        
        if tableView == resultsTable {
            if resultsTable.selectedRow >= 0 {
                let result = results[resultsTable.selectedRow]
                showResultDetails(result)
            }
        }
    }
}