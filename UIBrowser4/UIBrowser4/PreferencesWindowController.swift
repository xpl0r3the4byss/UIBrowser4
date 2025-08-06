import Cocoa

/// Window controller for preferences window
class PreferencesWindowController: NSWindowController {
    // MARK: - Types
    
    /// Preference pane identifiers
    enum PreferencePane: String {
        case appearance = "Appearance"
        case updates = "Updates"
        case scripting = "Scripting"
        case target = "Target"
        case advanced = "Advanced"
        
        var viewController: NSViewController {
            switch self {
            case .appearance:
                return AppearancePreferencesViewController()
            case .updates:
                return UpdatePreferencesViewController()
            case .scripting:
                return ScriptingPreferencesViewController()
            case .target:
                return TargetPreferencesViewController()
            case .advanced:
                return AdvancedPreferencesViewController()
            }
        }
        
        var toolbarItemImage: NSImage {
            switch self {
            case .appearance:
                return NSImage(systemSymbolName: "paintbrush", accessibilityDescription: "Appearance")!
            case .updates:
                return NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Updates")!
            case .scripting:
                return NSImage(systemSymbolName: "curlybraces", accessibilityDescription: "Scripting")!
            case .target:
                return NSImage(systemSymbolName: "target", accessibilityDescription: "Target")!
            case .advanced:
                return NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Advanced")!
            }
        }
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = PreferencesWindowController()
    
    /// Current preference pane
    private var currentPane: PreferencePane = .appearance
    
    // MARK: - Initialization
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        
        super.init(window: window)
        
        setupToolbar()
        showPreferencePane(.appearance)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "PreferencesToolbar")
        toolbar.delegate = self
        toolbar.selectedItemIdentifier = .appearance
        window?.toolbar = toolbar
    }
    
    // MARK: - Window Management
    
    /// Show preferences window
    func showWindow(preferencePane: PreferencePane? = nil) {
        if let pane = preferencePane {
            showPreferencePane(pane)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Show preference pane
    private func showPreferencePane(_ pane: PreferencePane) {
        currentPane = pane
        window?.contentViewController = pane.viewController
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(pane.rawValue)
    }
}

// MARK: - NSToolbarDelegate

extension PreferencesWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = PreferencePane(rawValue: itemIdentifier.rawValue) else {
            return nil
        }
        
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.rawValue
        item.image = pane.toolbarItemImage
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        
        return item
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return PreferencePane.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
    
    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let pane = PreferencePane(rawValue: sender.itemIdentifier.rawValue) else {
            return
        }
        showPreferencePane(pane)
    }
}

// MARK: - Supporting Types

extension PreferencePane: CaseIterable {}