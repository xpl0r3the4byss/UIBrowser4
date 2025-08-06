import Foundation
import Combine

/// Manages application preferences and settings
@MainActor
final class PreferencesManager {
    // MARK: - Types
    
    /// Preference keys
    enum Key: String {
        // Display
        case showPathControls = "ShowPathControls"
        case showToolbar = "ShowToolbar"
        case showStatusBar = "ShowStatusBar"
        case columnWidth = "ColumnWidth"
        case rowHeight = "RowHeight"
        
        // Updates
        case autoRefresh = "AutoRefresh"
        case refreshInterval = "RefreshInterval"
        case highlightChanges = "HighlightChanges"
        case showNotifications = "ShowNotifications"
        
        // Scripting
        case scriptStyle = "ScriptStyle"
        case includeComments = "IncludeComments"
        case useNumericIndices = "UseNumericIndices"
        case indentationStyle = "IndentationStyle"
        
        // Target Selection
        case restoreLastTarget = "RestoreLastTarget"
        case highlightTarget = "HighlightTarget"
        case rememberWindowLayout = "RememberWindowLayout"
        case showRecentTargets = "ShowRecentTargets"
        
        // Advanced
        case cacheSize = "CacheSize"
        case logLevel = "LogLevel"
        case developerExtras = "DeveloperExtras"
        case experimentalFeatures = "ExperimentalFeatures"
    }
    
    /// Preference domain
    enum Domain: String {
        case standard
        case temporary
        case volatile
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = PreferencesManager()
    
    /// Default values
    private let defaults: [Key: Any] = [
        .showPathControls: true,
        .showToolbar: true,
        .showStatusBar: true,
        .columnWidth: 200,
        .rowHeight: 20,
        
        .autoRefresh: true,
        .refreshInterval: 1.0,
        .highlightChanges: true,
        .showNotifications: true,
        
        .scriptStyle: "SystemEvents",
        .includeComments: true,
        .useNumericIndices: false,
        .indentationStyle: "Spaces",
        
        .restoreLastTarget: true,
        .highlightTarget: true,
        .rememberWindowLayout: true,
        .showRecentTargets: true,
        
        .cacheSize: 50 * 1024 * 1024, // 50MB
        .logLevel: "Info",
        .developerExtras: false,
        .experimentalFeatures: false
    ]
    
    /// Preference storage
    private var storage: [Domain: [Key: Any]] = [
        .standard: [:],
        .temporary: [:],
        .volatile: [:]
    ]
    
    /// Value publishers
    private var publishers: [Key: CurrentValueSubject<Any, Never>] = [:]
    
    /// Autosave timer
    private var autosaveTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        loadPreferences()
        setupAutosave()
    }
    
    deinit {
        autosaveTimer?.invalidate()
    }
    
    // MARK: - Preference Access
    
    /// Get preference value
    func value<T>(for key: Key, domain: Domain = .standard) -> T? {
        // Check domains in order
        for searchDomain in [domain, .temporary, .standard] {
            if let value = storage[searchDomain]?[key] as? T {
                return value
            }
        }
        
        // Return default
        return defaults[key] as? T
    }
    
    /// Set preference value
    func setValue(_ value: Any?, for key: Key, domain: Domain = .standard) {
        storage[domain]?[key] = value
        
        // Update publisher
        if let publisher = publishers[key] {
            publisher.send(value as Any)
        }
        
        // Schedule save if needed
        if domain == .standard {
            scheduleAutosave()
        }
    }
    
    /// Remove preference value
    func removeValue(for key: Key, domain: Domain = .standard) {
        storage[domain]?[key] = nil
        
        // Update publisher with default
        if let publisher = publishers[key] {
            publisher.send(defaults[key] as Any)
        }
        
        // Schedule save if needed
        if domain == .standard {
            scheduleAutosave()
        }
    }
    
    /// Get value publisher
    func publisher<T>(for key: Key) -> AnyPublisher<T, Never> {
        let publisher = publishers[key] ?? CurrentValueSubject<Any, Never>(
            value(for: key) ?? defaults[key] as Any
        )
        publishers[key] = publisher
        
        return publisher
            .compactMap { $0 as? T }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Persistence
    
    /// Load preferences from disk
    private func loadPreferences() {
        if let data = try? Data(contentsOf: preferencesURL),
           let prefs = try? PropertyListDecoder().decode([String: Any].self, from: data) as? [Key: Any] {
            storage[.standard] = prefs
        }
    }
    
    /// Save preferences to disk
    private func savePreferences() {
        guard let prefs = storage[.standard] else { return }
        
        do {
            let data = try PropertyListEncoder().encode(prefs)
            try data.write(to: preferencesURL)
        } catch {
            print("Error saving preferences: \(error)")
        }
    }
    
    /// Setup autosave timer
    private func setupAutosave() {
        autosaveTimer = Timer.scheduledTimer(
            withTimeInterval: 30.0,
            repeats: true
        ) { [weak self] _ in
            self?.savePreferences()
        }
    }
    
    /// Schedule autosave
    private func scheduleAutosave() {
        autosaveTimer?.fireDate = Date().addingTimeInterval(30.0)
    }
    
    // MARK: - Reset
    
    /// Reset domain to defaults
    func resetDomain(_ domain: Domain) {
        storage[domain] = [:]
        
        // Update publishers
        for (key, publisher) in publishers {
            publisher.send(defaults[key] as Any)
        }
        
        // Save if needed
        if domain == .standard {
            savePreferences()
        }
    }
    
    /// Reset all preferences
    func resetAll() {
        for domain in Domain.allCases {
            resetDomain(domain)
        }
    }
    
    // MARK: - Import/Export
    
    /// Export preferences
    func exportPreferences() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return try encoder.encode(storage[.standard])
    }
    
    /// Import preferences
    func importPreferences(_ data: Data) throws {
        let prefs = try PropertyListDecoder().decode([Key: Any].self, from: data)
        storage[.standard] = prefs
        
        // Update publishers
        for (key, value) in prefs {
            publishers[key]?.send(value)
        }
        
        savePreferences()
    }
    
    // MARK: - Helpers
    
    private var preferencesURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("UI Browser 4")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("Preferences.plist")
    }
}

// MARK: - Supporting Types

extension PreferencesManager.Domain: CaseIterable {}
extension PreferencesManager.Key: CaseIterable {}