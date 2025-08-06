import Cocoa
import Combine

/// View controller for managing saved scripts
class SavedScriptsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    // MARK: - Properties
    
    /// Shared instance
    static private(set) var sharedInstance: SavedScriptsViewController!
    
    /// Displayed scripts
    private var scripts: [ScriptWindowManager.SavedScript] = []
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var openButton: NSButton!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SavedScriptsViewController.sharedInstance = self
        setupUI()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure table columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 150
        
        let targetColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("target"))
        targetColumn.title = "Target App"
        targetColumn.width = 100
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Created"
        dateColumn.width = 150
        
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(targetColumn)
        tableView.addTableColumn(dateColumn)
        
        // Configure buttons
        deleteButton.isEnabled = false
        openButton.isEnabled = false
    }
    
    private func setupObservers() {
        // Observe saved scripts
        ScriptWindowManager.shared.savedScriptsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scripts in
                self?.scripts = scripts.sorted { $0.timestamp > $1.timestamp }
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @IBAction func deleteScript(_ sender: Any) {
        guard tableView.selectedRow >= 0 else { return }
        
        let script = scripts[tableView.selectedRow]
        
        do {
            try ScriptWindowManager.shared.deleteScript(script)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error Deleting Script"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    @IBAction func openScript(_ sender: Any) {
        guard tableView.selectedRow >= 0 else { return }
        
        let script = scripts[tableView.selectedRow]
        ScriptWindowManager.shared.loadScript(script)
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return scripts.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let script = scripts[row]
        
        let cellView = tableView.makeView(withIdentifier: tableColumn?.identifier ?? NSUserInterfaceItemIdentifier(""), owner: self) as? NSTableCellView
        
        switch tableColumn?.identifier.rawValue {
        case "name":
            cellView?.textField?.stringValue = script.name
        case "target":
            cellView?.textField?.stringValue = script.targetApp
        case "date":
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            cellView?.textField?.stringValue = formatter.string(from: script.timestamp)
        default:
            break
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        deleteButton.isEnabled = hasSelection
        openButton.isEnabled = hasSelection
    }
}