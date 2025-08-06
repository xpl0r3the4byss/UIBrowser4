import Cocoa
import Combine

/// Base class implementing common functionality for element viewing controllers
class BaseElementViewController: NSViewController, ElementViewProtocol {
    // MARK: - Properties
    
    /// Required by ElementViewProtocol but must be implemented by subclasses
    static var sharedInstance: Self!
    
    /// Path control - must be implemented by subclasses
    var pathControl: NSPathControl {
        fatalError("pathControl must be implemented by subclasses")
    }
    
    /// Path control manager
    var elementPathControlManager: ElementPathControlManager = ElementPathControlManager()
    
    /// Flag indicating manual selection
    var isManualSelection: Bool = false
    
    /// Flag indicating if focus tracking is enabled
    var isFocusTrackingEnabled: Bool = false {
        didSet {
            updateFocusTracking()
        }
    }
    
    // MARK: - Element Highlighting
    
    /// Highlight current element
    func highlightCurrentElement() {
        Task {
            let dataSource = ElementDataModel.sharedInstance
            if let currentNode = await dataSource.currentElementNode,
               let element = dataSource.element(ofNode: currentNode) {
                await ElementHighlightService.shared.highlightElement(element)
            }
        }
    }
    
    /// Toggle focus tracking for current element
    private func updateFocusTracking() {
        Task {
            let dataSource = ElementDataModel.sharedInstance
            if isFocusTrackingEnabled,
               let currentNode = await dataSource.currentElementNode,
               let element = dataSource.element(ofNode: currentNode) {
                await ElementHighlightService.shared.startTrackingFocus(for: element)
            } else {
                await ElementHighlightService.shared.stopTrackingFocus()
            }
        }
    }
    
    // MARK: - Path Control Implementation
    
    func updateTargetSelection() {
        elementPathControlManager.updateTargetSelection(for: pathControl)
    }
    
    func displayPathControl() {
        elementPathControlManager.displayPathControl(pathControl)
    }
    
    func clearPathControl() {
        elementPathControlManager.clearPathControl(pathControl)
    }
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Loading indicator
    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    
    // MARK: - ElementViewProtocol Implementation
    
    @MainActor
    func updateView() async throws {
        let dataSource = ElementDataModel.sharedInstance
        
        dataSource.setLoading(true)
        defer { dataSource.setLoading(false) }
        
        do {
            // Update path control
            updateTargetSelection()
            
            // Update element state
            if let currentNode = await dataSource.currentElementNode {
                let element = dataSource.element(ofNode: currentNode)
                let path = await dataSource.currentElementIndexPath
                dataSource.setCurrentElement(element, path: path)
            } else {
                dataSource.setCurrentElement(nil, path: nil)
            }
            
            // Subclasses should override this method and call super before their implementation
        } catch {
            dataSource.setError(error)
            throw error
        }
    }
    
    @MainActor 
    func showView() async throws {
        // To be implemented by subclasses
        fatalError("showView() must be implemented by subclasses")
    }
    
    func clearView() {
        // To be implemented by subclasses
        fatalError("clearView() must be implemented by subclasses")
    }
    
    @MainActor
    func selectElement(_ sender: NSMenuItem) async throws {
        try await withState { state in
            state.startUpdate()
            defer { state.endUpdate() }
            
            let dataSource = ElementDataModel.sharedInstance
            await dataSource.unsaveCurrentElementIndexPath()
            
            guard let selectedNode = sender.representedObject as? ElementDataModel.ElementNodeInfo else {
                throw ViewError.unexpectedNilValue
            }
            
            let selectedIndexPath = await dataSource.indexPath(ofNode: selectedNode)
            let selectedLevel = selectedIndexPath.length - 1
            let selectedIndex = selectedIndexPath.index(atPosition: selectedLevel)
            
            try await dataSource.updateDataModelForCurrentElementAt(level: selectedLevel, index: selectedIndex)
            try await showView()
        }
    }
    
    // MARK: - Error Handling
    
    enum ViewError: LocalizedError {
        case elementInvalid
        case elementDestroyed
        case invalidSelection
        case nodeNotFound
        case unexpectedNilValue
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .elementInvalid:
                return "Invalid accessibility element"
            case .elementDestroyed:
                return "Element has been destroyed"
            case .invalidSelection:
                return "Invalid selection"
            case .nodeNotFound:
                return "Node not found in data model"
            case .unexpectedNilValue:
                return "Unexpected nil value encountered"
            case .unknownError:
                return "Unknown error occurred"
            }
        }
    }
    
    func handleError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error in Element View"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    // MARK: - Utilities
    
    /// Helper method to execute code with managed state
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStateObservation()
        setupLoadingIndicator()
    }
    
    private func setupStateObservation() {
        // Observe loading state
        ElementDataModel.statePublisher
            .map(\.isLoading)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimation(nil)
                } else {
                    self?.loadingIndicator.stopAnimation(nil)
                }
            }
            .store(in: &cancellables)
        
        // Observe errors
        ElementDataModel.statePublisher
            .compactMap(\.error)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
        
        // Observe current element
        ElementDataModel.statePublisher
            .map(\.currentElement)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] element in
                Task {
                    await AttributeInspectorViewController.sharedInstance?.updateInspector(for: element)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupLoadingIndicator() {
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}