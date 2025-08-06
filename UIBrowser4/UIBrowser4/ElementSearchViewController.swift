import Cocoa
import Combine

/// View controller for element search and filtering
class ElementSearchViewController: NSViewController {
    // MARK: - Properties
    
    private var subscriptions = Set<AnyCancellable>()
    private var currentPreset: ElementFilterManager.FilterPreset?
    
    // MARK: - Outlets
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var rolePopup: NSPopUpButton!
    @IBOutlet weak var subrolePopup: NSPopUpButton!
    @IBOutlet weak var enabledCheckbox: NSButton!
    @IBOutlet weak var focusedCheckbox: NSButton!
    @IBOutlet weak var visibleCheckbox: NSButton!
    @IBOutlet weak var regexCheckbox: NSButton!
    @IBOutlet weak var caseSensitiveCheckbox: NSButton!
    @IBOutlet weak var attributeTable: NSTableView!
    @IBOutlet weak var presetPopup: NSPopUpButton!
    @IBOutlet weak var savePresetButton: NSButton!
    @IBOutlet weak var deletePresetButton: NSButton!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure tables
        attributeTable.delegate = self
        attributeTable.dataSource = self
        
        // Configure popups
        setupRolePopup()
        setupSubrolePopup()
        setupPresetPopup()
        
        // Load current filter
        let filter = ElementFilterManager.shared.currentCriteria
        searchField.stringValue = filter.searchText
        enabledCheckbox.state = filter.enabledOnly ? .on : .off
        focusedCheckbox.state = filter.focusedOnly ? .on : .off
        visibleCheckbox.state = filter.visibleOnly ? .on : .off
        regexCheckbox.state = filter.useRegex ? .on : .off
        caseSensitiveCheckbox.state = filter.caseSensitive ? .on : .off
        
        if let role = filter.roles.first {
            rolePopup.selectItem(withTitle: role)
        }
        if let subrole = filter.subroles.first {
            subrolePopup.selectItem(withTitle: subrole)
        }
        
        attributeTable.reloadData()
    }
    
    private func setupBindings() {
        // Handle search changes
        NotificationCenter.default.publisher(for: NSSearchField.textDidChangeNotification, object: searchField)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFilter()
            }
            .store(in: &subscriptions)
        
        // Handle filter results
        ElementFilterManager.shared.resultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elements in
                self?.updateResults(elements)
            }
            .store(in: &subscriptions)
    }
    
    private func setupRolePopup() {
        rolePopup.removeAllItems()
        rolePopup.addItem(withTitle: "Any")
        
        let roles = Set(ElementDataModel.sharedInstance.allElements.compactMap { $0.AXRole })
        rolePopup.addItems(withTitles: Array(roles).sorted())
    }
    
    private func setupSubrolePopup() {
        subrolePopup.removeAllItems()
        subrolePopup.addItem(withTitle: "Any")
        
        let subroles = Set(ElementDataModel.sharedInstance.allElements.compactMap { $0.AXSubrole })
        subrolePopup.addItems(withTitles: Array(subroles).sorted())
    }
    
    private func setupPresetPopup() {
        presetPopup.removeAllItems()
        presetPopup.addItem(withTitle: "Custom")
        
        let presets = ElementFilterManager.shared.presets
        if !presets.isEmpty {
            presetPopup.menu?.addItem(NSMenuItem.separator())
            for preset in presets {
                presetPopup.addItem(withTitle: preset.name)
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction func roleChanged(_ sender: NSPopUpButton) {
        var filter = ElementFilterManager.shared.currentCriteria
        if sender.titleOfSelectedItem == "Any" {
            filter.roles = []
        } else if let role = sender.titleOfSelectedItem {
            filter.roles = [role]
        }
        ElementFilterManager.shared.updateCriteria(filter)
        updateFilter()
    }
    
    @IBAction func subroleChanged(_ sender: NSPopUpButton) {
        var filter = ElementFilterManager.shared.currentCriteria
        if sender.titleOfSelectedItem == "Any" {
            filter.subroles = []
        } else if let subrole = sender.titleOfSelectedItem {
            filter.subroles = [subrole]
        }
        ElementFilterManager.shared.updateCriteria(filter)
        updateFilter()
    }
    
    @IBAction func optionChanged(_ sender: NSButton) {
        var filter = ElementFilterManager.shared.currentCriteria
        
        switch sender {
        case enabledCheckbox:
            filter.enabledOnly = sender.state == .on
        case focusedCheckbox:
            filter.focusedOnly = sender.state == .on
        case visibleCheckbox:
            filter.visibleOnly = sender.state == .on
        case regexCheckbox:
            filter.useRegex = sender.state == .on
        case caseSensitiveCheckbox:
            filter.caseSensitive = sender.state == .on
        default:
            break
        }
        
        ElementFilterManager.shared.updateCriteria(filter)
        updateFilter()
    }
    
    @IBAction func presetSelected(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem > 0 else {
            currentPreset = nil
            deletePresetButton.isEnabled = false
            return
        }
        
        if let preset = ElementFilterManager.shared.presets.first(where: { $0.name == sender.titleOfSelectedItem }) {
            currentPreset = preset
            ElementFilterManager.shared.loadPreset(preset)
            deletePresetButton.isEnabled = true
            setupUI()
        }
    }
    
    @IBAction func savePreset(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Save Filter Preset"
        alert.informativeText = "Enter a name for this filter preset:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        
        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                let name = input.stringValue.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    ElementFilterManager.shared.savePreset(
                        name: name,
                        criteria: ElementFilterManager.shared.currentCriteria
                    )
                    self.setupPresetPopup()
                    self.presetPopup.selectItem(withTitle: name)
                    self.currentPreset = ElementFilterManager.shared.presets.first { $0.name == name }
                    self.deletePresetButton.isEnabled = true
                }
            }
        }
    }
    
    @IBAction func deletePreset(_ sender: Any) {
        guard let preset = currentPreset else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Filter Preset"
        alert.informativeText = "Are you sure you want to delete the preset '\(preset.name)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                ElementFilterManager.shared.deletePreset(preset)
                self.setupPresetPopup()
                self.presetPopup.selectItem(at: 0)
                self.currentPreset = nil
                self.deletePresetButton.isEnabled = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateFilter() {
        var filter = ElementFilterManager.shared.currentCriteria
        filter.searchText = searchField.stringValue
        ElementFilterManager.shared.updateCriteria(filter)
        
        Task {
            await ElementFilterManager.shared.applyFilter(
                to: ElementDataModel.sharedInstance.allElements
            )
        }
    }
    
    private func updateResults(_ elements: [AccessibleElement]) {
        // Update results display
        // This would typically update a table/outline view showing the filtered elements
    }
}

// MARK: - NSTableViewDataSource

extension ElementSearchViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return ElementFilterManager.shared.currentCriteria.attributeFilters.count
    }
}

// MARK: - NSTableViewDelegate

extension ElementSearchViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: self) as? NSTableCellView
        
        let filters = Array(ElementFilterManager.shared.currentCriteria.attributeFilters)
        let (attribute, value) = filters[row]
        
        switch tableColumn?.identifier.rawValue {
        case "attribute":
            cell?.textField?.stringValue = attribute
        case "value":
            cell?.textField?.stringValue = value
        default:
            break
        }
        
        return cell
    }
}