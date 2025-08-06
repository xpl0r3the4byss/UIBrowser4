import Cocoa
import Combine

/// Manages script windows and their lifecycle
@MainActor
class ScriptWindowManager {
    // MARK: - Types
    
    /// Represents a saved script
    struct SavedScript: Codable {
        var name: String
        var script: String
        var timestamp: Date
        var targetApp: String
        var elementPath: String
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ScriptWindowManager()
    
    /// Currently open script windows
    private var scriptWindows: [NSWindow] = []
    
    /// Saved scripts
    private var savedScripts: [SavedScript] = []
    
    /// Script window publishers
    let windowCountPublisher = CurrentValueSubject<Int, Never>(0)
    let savedScriptsPublisher = CurrentValueSubject<[SavedScript], Never>([])
    
    // MARK: - Initialization
    
    private init() {
        loadSavedScripts()
    }
    
    // MARK: - Window Management
    
    /// Create a new script window
    func createScriptWindow() -> NSWindow {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        window.title = "Script Editor"
        window.center()
        
        // Load script editor view controller
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let scriptVC = storyboard.instantiateController(withIdentifier: "ScriptGeneratorViewController") as! ScriptGeneratorViewController
        window.contentViewController = scriptVC
        
        // Add to tracking
        scriptWindows.append(window)
        windowCountPublisher.send(scriptWindows.count)
        
        // Add window delegate
        window.delegate = ScriptWindowDelegate { [weak self] window in
            self?.scriptWindows.removeAll { $0 == window }
            self?.windowCountPublisher.send(self?.scriptWindows.count ?? 0)
        }
        
        return window
    }
    
    /// Show script window for specific element
    func showScriptWindow(for element: AccessibleElement) {
        let window = createScriptWindow()
        window.makeKeyAndOrderFront(nil)
        
        // Update data model
        Task {
            await ElementDataModel.sharedInstance.setCurrentElement(element, path: nil)
        }
    }
    
    // MARK: - Script Management
    
    /// Save a script
    func saveScript(_ script: String, name: String) async throws {
        guard let element = ElementDataModel.statePublisher.value.currentElement else {
            throw ScriptError.noElementSelected
        }
        
        let savedScript = SavedScript(
            name: name,
            script: script,
            timestamp: Date(),
            targetApp: await element.processName() ?? "Unknown",
            elementPath: try await element.elementPath()
        )
        
        savedScripts.append(savedScript)
        savedScriptsPublisher.send(savedScripts)
        
        try saveToDisk()
    }
    
    /// Load a saved script
    func loadScript(_ savedScript: SavedScript) {
        let window = createScriptWindow()
        window.makeKeyAndOrderFront(nil)
        
        if let scriptVC = window.contentViewController as? ScriptGeneratorViewController {
            scriptVC.scriptTextView.string = savedScript.script
        }
    }
    
    /// Delete a saved script
    func deleteScript(_ script: SavedScript) throws {
        savedScripts.removeAll { $0.name == script.name }
        savedScriptsPublisher.send(savedScripts)
        try saveToDisk()
    }
    
    // MARK: - Persistence
    
    private var scriptsURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("UI Browser 4")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("saved_scripts.json")
    }
    
    private func loadSavedScripts() {
        do {
            let data = try Data(contentsOf: scriptsURL)
            savedScripts = try JSONDecoder().decode([SavedScript].self, from: data)
            savedScriptsPublisher.send(savedScripts)
        } catch {
            // Ignore errors on first load
            savedScripts = []
        }
    }
    
    private func saveToDisk() throws {
        let data = try JSONEncoder().encode(savedScripts)
        try data.write(to: scriptsURL)
    }
}

// MARK: - Supporting Types

enum ScriptError: LocalizedError {
    case noElementSelected
    
    var errorDescription: String? {
        switch self {
        case .noElementSelected:
            return "No element is currently selected"
        }
    }
}

class ScriptWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: (NSWindow) -> Void
    
    init(onClose: @escaping (NSWindow) -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            onClose(window)
        }
    }
}