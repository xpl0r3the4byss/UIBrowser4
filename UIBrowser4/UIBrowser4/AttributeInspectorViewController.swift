import Cocoa

/// View controller for inspecting accessibility element attributes
class AttributeInspectorViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation {
    // MARK: - Properties
    
    /// Shared instance
    static private(set) var sharedInstance: AttributeInspectorViewController!
    
    /// Table columns
    private enum ColumnIdentifiers {
        static let attribute = NSUserInterfaceItemIdentifier("attribute")
        static let value = NSUserInterfaceItemIdentifier("value")
    }
    
    /// Current element being inspected
    private var currentElement: AccessibleElement?
    
    /// Displayed attributes in order
    private var displayedAttributes: [AttributeModel.AttributeType] = []
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: NSTableView!
    
    /// Search field
    @IBOutlet weak var searchField: NSSearchField!
    
    /// Context menu for the table view
    private lazy var tableContextMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copySelectedValue(_:)), keyEquivalent: "c")
        return menu
    }()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        AttributeInspectorViewController.sharedInstance = self
        
        // Configure table view
        tableView.menu = tableContextMenu
        tableView.target = self
        tableView.doubleAction = #selector(copySelectedValue(_:))
        
        // Configure search field
        searchField.target = self
        searchField.action = #selector(searchFieldDidChange(_:))
        
        // Set initial attributes
        displayedAttributes = Array(AttributeModel.AttributeType.allCases)
        
        // Subscribe to filtered attributes updates
        AttributeModel.shared.filteredAttributesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filteredTypes in
                self?.displayedAttributes = filteredTypes
                self?.tableView.reloadData()
            }
            .store(in: &subscriptions)
    }
    
    /// Search field value changed
    @objc private func searchFieldDidChange(_ sender: NSSearchField) {
        AttributeModel.shared.filterAttributes(searchTerm: sender.stringValue)
    }
    
    /// Cancellation storage
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Update inspector for a new element
    @MainActor
    func updateInspector(for element: AccessibleElement?) async {
        currentElement = element
        
        if let element = element {
            do {
                try await AttributeModel.shared.updateAttributes(for: element)
                tableView.reloadData()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Loading Attributes"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        } else {
            tableView.reloadData()
        }
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard currentElement != nil else { return 0 }
        return displayedAttributes.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier else { return nil }
        
        let cellView = tableView.makeView(withIdentifier: columnIdentifier, owner: self) as? NSTableCellView
        
        switch columnIdentifier {
        case ColumnIdentifiers.attribute:
            cellView?.textField?.stringValue = displayedAttributes[row].rawValue.replacingOccurrences(of: "AX", with: "")
            
        case ColumnIdentifiers.value:
            cellView?.textField?.stringValue = AttributeModel.shared.formattedValue(for: displayedAttributes[row])
            cellView?.textField?.isSelectable = true
            
        default:
            break
        }
        
        return cellView
    }
    
    // MARK: - Copy Support
    
    /// Copy the selected value to the clipboard
    @objc private func copySelectedValue(_ sender: Any?) {
        guard tableView.selectedRow >= 0 else { return }
        
        let attributeType = displayedAttributes[tableView.selectedRow]
        let value = AttributeModel.shared.formattedValue(for: attributeType)
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
    
    /// Validate menu items
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copySelectedValue(_:)) {
            return tableView.selectedRow >= 0
        }
        return true
    }
}