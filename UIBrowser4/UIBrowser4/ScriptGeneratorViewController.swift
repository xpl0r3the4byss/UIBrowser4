import Cocoa
import Combine

/// View controller for generating and managing AppleScripts
class ScriptGeneratorViewController: NSViewController {
    // MARK: - Properties
    
    /// Shared instance
    static private(set) var sharedInstance: ScriptGeneratorViewController!
    
    /// Generator options
    private var options = AppleScriptGenerator.Options() {
        didSet {
            AppleScriptGenerator.shared.options = options
            updateScript()
        }
    }
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Outlets
    
    @IBOutlet weak var scriptTextView: NSTextView!
    @IBOutlet weak var stylePopUpButton: NSPopUpButton!
    @IBOutlet weak var includeCommentsCheckbox: NSButton!
    @IBOutlet weak var includeErrorHandlingCheckbox: NSButton!
    @IBOutlet weak var useNumericIndicesCheckbox: NSButton!
    @IBOutlet weak var waitForElementCheckbox: NSButton!
    @IBOutlet weak var timeoutTextField: NSTextField!
    @IBOutlet weak var copyButton: NSButton!
    @IBOutlet weak var runButton: NSButton!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ScriptGeneratorViewController.sharedInstance = self
        setupUI()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure style popup
        stylePopUpButton.removeAllItems()
        stylePopUpButton.addItems(withTitles: ["System Events", "AX Elements"])
        stylePopUpButton.selectItem(at: 0)
        
        // Configure checkboxes
        includeCommentsCheckbox.state = options.includeComments ? .on : .off
        includeErrorHandlingCheckbox.state = options.includeErrorHandling ? .on : .off
        useNumericIndicesCheckbox.state = options.useNumericIndices ? .on : .off
        waitForElementCheckbox.state = options.waitForElement ? .on : .off
        
        // Configure timeout
        timeoutTextField.stringValue = String(format: "%.1f", options.timeout)
        
        // Configure script view
        scriptTextView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        scriptTextView.isEditable = false
    }
    
    private func setupObservers() {
        // Observe current element changes
        ElementDataModel.statePublisher
            .compactMap(\\.currentElement)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] element in
                self?.updateScript()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @IBAction func styleChanged(_ sender: NSPopUpButton) {
        options.style = sender.indexOfSelectedItem == 0 ? .systemEvents : .axElement
    }
    
    @IBAction func includeCommentsChanged(_ sender: NSButton) {
        options.includeComments = sender.state == .on
    }
    
    @IBAction func includeErrorHandlingChanged(_ sender: NSButton) {
        options.includeErrorHandling = sender.state == .on
    }
    
    @IBAction func useNumericIndicesChanged(_ sender: NSButton) {
        options.useNumericIndices = sender.state == .on
    }
    
    @IBAction func waitForElementChanged(_ sender: NSButton) {
        options.waitForElement = sender.state == .on
    }
    
    @IBAction func timeoutChanged(_ sender: NSTextField) {
        if let timeout = TimeInterval(sender.stringValue) {
            options.timeout = timeout
        }
    }
    
    @IBAction func copyScript(_ sender: Any) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(scriptTextView.string, forType: .string)
    }
    
    @IBAction func runScript(_ sender: Any) {
        Task {
            do {
                try await executeScript()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Running Script"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateScript() {
        Task {
            do {
                if let element = ElementDataModel.statePublisher.value.currentElement {
                    let script = try await AppleScriptGenerator.shared.generateScript(for: element)
                    scriptTextView.string = script
                    copyButton.isEnabled = true
                    runButton.isEnabled = true
                } else {
                    scriptTextView.string = "// Select an element to generate script"
                    copyButton.isEnabled = false
                    runButton.isEnabled = false
                }
            } catch {
                scriptTextView.string = "// Error generating script: \(error.localizedDescription)"
                copyButton.isEnabled = false
                runButton.isEnabled = false
            }
        }
    }
    
    private func executeScript() async throws {
        guard !scriptTextView.string.isEmpty else { return }
        
        let script = NSAppleScript(source: scriptTextView.string)
        var error: NSDictionary?
        
        script?.executeAndReturnError(&error)
        
        if let error = error {
            throw NSError(domain: "AppleScriptError",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"])
        }
    }
}