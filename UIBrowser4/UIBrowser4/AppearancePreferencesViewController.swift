import Cocoa
import Combine

/// View controller for appearance preferences
class AppearancePreferencesViewController: NSViewController {
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Outlets
    
    @IBOutlet weak var appearanceSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var accentColorPopup: NSPopUpButton!
    @IBOutlet weak var followSystemCheckbox: NSButton!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure appearance control
        appearanceSegmentedControl.segmentCount = 2
        appearanceSegmentedControl.setLabel("Light", forSegment: 0)
        appearanceSegmentedControl.setLabel("Dark", forSegment: 1)
        
        // Configure accent colors
        accentColorPopup.removeAllItems()
        for color in NSColor.AccentColor.allCases {
            accentColorPopup.addItem(withTitle: color.displayName)
            accentColorPopup.lastItem?.tag = color.rawValue
        }
        
        // Set initial values
        let config = ThemeManager.shared.config
        followSystemCheckbox.state = config.followSystem ? .on : .off
        appearanceSegmentedControl.selectedSegment = config.prefersDarkMode ? 1 : 0
        appearanceSegmentedControl.isEnabled = !config.followSystem
        accentColorPopup.selectItem(withTag: config.accentColor)
    }
    
    private func setupBindings() {
        // Update when theme changes
        ThemeManager.shared.colorsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] colors in
                self?.view.needsDisplay = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @IBAction func appearanceChanged(_ sender: NSSegmentedControl) {
        let isDark = sender.selectedSegment == 1
        if isDark != ThemeManager.shared.config.prefersDarkMode {
            ThemeManager.shared.toggleTheme()
        }
    }
    
    @IBAction func followSystemChanged(_ sender: NSButton) {
        if sender.state == .on {
            ThemeManager.shared.enableSystemTheme()
            appearanceSegmentedControl.isEnabled = false
        } else {
            ThemeManager.shared.config.followSystem = false
            appearanceSegmentedControl.isEnabled = true
        }
    }
    
    @IBAction func accentColorChanged(_ sender: NSPopUpButton) {
        if let color = NSColor.AccentColor(rawValue: sender.selectedTag()) {
            ThemeManager.shared.setAccentColor(color)
        }
    }
}

// MARK: - Supporting Types

extension NSColor.AccentColor: CaseIterable {
    public static var allCases: [NSColor.AccentColor] = [
        .blue, .purple, .pink, .red, .orange, .yellow, .green, .graphite
    ]
    
    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .graphite: return "Graphite"
        @unknown default: return "Unknown"
        }
    }
}