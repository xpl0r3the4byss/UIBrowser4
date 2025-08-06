import Cocoa
import Combine

/// View controller for inspecting and executing element actions
class ActionInspectorViewController: NSViewController {
    // MARK: - Properties
    
    /// Shared instance
    static private(set) var sharedInstance: ActionInspectorViewController!
    
    /// Current element
    private var currentElement: AccessibleElement?
    
    /// Available actions
    private var availableActions: [ElementActionManager.Action] = []
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var executeButton: NSButton!
    @IBOutlet weak var valueTextField: NSTextField!
    @IBOutlet weak var valueLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ActionInspectorViewController.sharedInstance = self
        setupUI()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        
        // Configure value input
        valueTextField.isHidden = true
        valueLabel.isHidden = true
        
        // Configure status
        statusLabel.stringValue = ""
        progressIndicator.isHidden = true
        
        // Configure button
        executeButton.isEnabled = false
    }
    
    private func setupObservers() {
        // Observe current element changes
        ElementDataModel.statePublisher
            .compactMap(\\.currentElement)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] element in
                self?.updateElement(element)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @IBAction func executeAction(_ sender: Any) {
        guard let element = currentElement,
              let action = selectedAction else {
            return
        }
        
        // Show progress
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        executeButton.isEnabled = false
        
        // Execute action
        Task {
            do {
                let value = action.requiresValue ? valueTextField.stringValue : nil
                let result = try await ElementActionManager.shared.executeAction(action, on: element, value: value)
                
                // Show result
                statusLabel.textColor = result == .success ? .systemGreen : .systemRed
                statusLabel.stringValue = ElementActionManager.shared.formatResult(result)
                
                // Update highlight if needed
                if result == .success {
                    await ElementHighlightService.shared.highlightElement(element)
                }
            } catch {
                statusLabel.textColor = .systemRed
                statusLabel.stringValue = error.localizedDescription
            }
            
            // Hide progress
            progressIndicator.stopAnimation(nil)
            progressIndicator.isHidden = true
            executeButton.isEnabled = true
        }
    }
    
    // MARK: - Private Methods
    
    private func updateElement(_ element: AccessibleElement) {
        currentElement = element
        
        // Update available actions
        Task {
            availableActions = await ElementActionManager.shared.availableActions(for: element)
            tableView.reloadData()
        }
    }
    
    private var selectedAction: ElementActionManager.Action? {
        guard tableView.selectedRow >= 0,
              tableView.selectedRow < availableActions.count else {
            return nil
        }
        return availableActions[tableView.selectedRow]
    }
}

// MARK: - NSTableViewDataSource

extension ActionInspectorViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return availableActions.count
    }
}

// MARK: - NSTableViewDelegate

extension ActionInspectorViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let action = availableActions[row]
        
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
        cellView?.textField?.stringValue = action.description
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        // Update UI for selected action
        if let action = selectedAction {
            executeButton.isEnabled = true
            descriptionLabel.stringValue = action.description
            
            // Show/hide value input
            valueTextField.isHidden = !action.requiresValue
            valueLabel.isHidden = !action.requiresValue
            if let paramDesc = action.parameterDescription {
                valueLabel.stringValue = paramDesc
            }
        } else {
            executeButton.isEnabled = false
            descriptionLabel.stringValue = ""
            valueTextField.isHidden = true
            valueLabel.isHidden = true
        }
    }
}