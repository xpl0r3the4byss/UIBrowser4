import Cocoa
import Combine

/// Manages application theming and appearance
@MainActor
class ThemeManager {
    // MARK: - Types
    
    /// Theme colors for different interface states
    struct ThemeColors {
        let textColor: NSColor
        let backgroundColor: NSColor
        let alternateBackgroundColor: NSColor
        let highlightColor: NSColor
        let borderColor: NSColor
        let accentColor: NSColor
        
        static var light: ThemeColors {
            ThemeColors(
                textColor: .textColor,
                backgroundColor: .controlBackgroundColor,
                alternateBackgroundColor: .alternateSelectedControlColor,
                highlightColor: .selectedContentBackgroundColor,
                borderColor: .separatorColor,
                accentColor: .controlAccentColor
            )
        }
        
        static var dark: ThemeColors {
            ThemeColors(
                textColor: .labelColor,
                backgroundColor: .windowBackgroundColor,
                alternateBackgroundColor: .alternateSelectedControlColor,
                highlightColor: .selectedContentBackgroundColor,
                borderColor: .separatorColor,
                accentColor: .controlAccentColor
            )
        }
    }
    
    /// Theme configuration
    struct ThemeConfig: Codable {
        var followSystem: Bool = true
        var prefersDarkMode: Bool = false
        var accentColor: Int = 0 // Maps to NSColor.AccentColor
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ThemeManager()
    
    /// Current theme configuration
    private(set) var config = ThemeConfig() {
        didSet {
            saveConfig()
            updateTheme()
        }
    }
    
    /// Theme color publishers
    let colorsPublisher = CurrentValueSubject<ThemeColors, Never>(.light)
    
    /// Theme observation
    private var appearanceObserver: NSKeyValueObservation?
    
    // MARK: - Initialization
    
    private init() {
        loadConfig()
        setupObservers()
        updateTheme()
    }
    
    // MARK: - Theme Management
    
    /// Update application theme based on current config
    private func updateTheme() {
        // Determine if dark mode should be active
        let isDarkMode: Bool
        if config.followSystem {
            isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            isDarkMode = config.prefersDarkMode
        }
        
        // Update appearance
        NSApp.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        
        // Update accent color
        if let accentColor = NSColor.AccentColor(rawValue: config.accentColor) {
            NSApp.appearance?.setValue(accentColor, forKey: "NSAccentColorName")
        }
        
        // Update colors
        colorsPublisher.send(isDarkMode ? .dark : .light)
    }
    
    /// Toggle between light and dark mode
    func toggleTheme() {
        config.prefersDarkMode.toggle()
        config.followSystem = false
    }
    
    /// Enable system theme following
    func enableSystemTheme() {
        config.followSystem = true
        updateTheme()
    }
    
    /// Set accent color
    func setAccentColor(_ color: NSColor.AccentColor) {
        config.accentColor = color.rawValue
    }
    
    // MARK: - Persistence
    
    private var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("UI Browser 4")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("theme_config.json")
    }
    
    private func loadConfig() {
        do {
            let data = try Data(contentsOf: configURL)
            config = try JSONDecoder().decode(ThemeConfig.self, from: data)
        } catch {
            // Use defaults if config doesn't exist
            config = ThemeConfig()
        }
    }
    
    private func saveConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL)
        } catch {
            print("Error saving theme config: \(error)")
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observe system appearance changes
        appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            self?.updateTheme()
        }
    }
}

// MARK: - Color Extensions

extension NSColor {
    /// Create color that adapts to current theme
    static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
        return NSColor(name: nil) { appearance in
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}