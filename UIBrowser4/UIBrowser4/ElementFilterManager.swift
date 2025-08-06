import Foundation
import Combine

/// Manager for handling element filtering and search
@MainActor
final class ElementFilterManager {
    // MARK: - Types
    
    /// Filter criteria
    struct FilterCriteria: Codable {
        /// Search text
        var searchText = ""
        
        /// Filter by role
        var roles: Set<String> = []
        
        /// Filter by subrole
        var subroles: Set<String> = []
        
        /// Only show enabled elements
        var enabledOnly = false
        
        /// Only show focused elements
        var focusedOnly = false
        
        /// Only show visible elements
        var visibleOnly = true
        
        /// Filter by attribute values
        var attributeFilters: [String: String] = [:]
        
        /// Use regular expressions
        var useRegex = false
        
        /// Case sensitive search
        var caseSensitive = false
    }
    
    /// Filter preset
    struct FilterPreset: Codable {
        let name: String
        let criteria: FilterCriteria
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementFilterManager()
    
    /// Current filter criteria
    @Published private(set) var currentCriteria = FilterCriteria()
    
    /// Filter presets
    @Published private(set) var presets: [FilterPreset] = []
    
    /// Filter results publisher
    let resultsPublisher = PassthroughSubject<[AccessibleElement], Never>()
    
    // MARK: - Initialization
    
    private init() {
        loadPresets()
    }
    
    // MARK: - Filtering
    
    /// Apply filter to elements
    func applyFilter(to elements: [AccessibleElement]) async {
        var filtered = elements
        
        // Apply role filters
        if !currentCriteria.roles.isEmpty {
            filtered = filtered.filter { element in
                guard let role = element.AXRole else { return false }
                return currentCriteria.roles.contains(role)
            }
        }
        
        // Apply subrole filters
        if !currentCriteria.subroles.isEmpty {
            filtered = filtered.filter { element in
                guard let subrole = element.AXSubrole else { return false }
                return currentCriteria.subroles.contains(subrole)
            }
        }
        
        // Apply enabled filter
        if currentCriteria.enabledOnly {
            filtered = filtered.filter { element in
                return element.AXEnabled ?? false
            }
        }
        
        // Apply focused filter
        if currentCriteria.focusedOnly {
            filtered = filtered.filter { element in
                return element.AXFocused ?? false
            }
        }
        
        // Apply visibility filter
        if currentCriteria.visibleOnly {
            filtered = filtered.filter { element in
                let size = element.AXSize as? CGSize ?? .zero
                let position = element.AXPosition as? CGPoint ?? .zero
                return size.width > 0 && size.height > 0 && position != .zero
            }
        }
        
        // Apply attribute filters
        for (attribute, value) in currentCriteria.attributeFilters {
            filtered = filtered.filter { element in
                guard let attrValue = element.value(forKey: attribute) as? String else {
                    return false
                }
                
                if currentCriteria.useRegex {
                    guard let regex = try? NSRegularExpression(pattern: value) else {
                        return false
                    }
                    let range = NSRange(attrValue.startIndex..., in: attrValue)
                    return regex.firstMatch(in: attrValue, range: range) != nil
                } else if currentCriteria.caseSensitive {
                    return attrValue.contains(value)
                } else {
                    return attrValue.lowercased().contains(value.lowercased())
                }
            }
        }
        
        // Apply text search
        if !currentCriteria.searchText.isEmpty {
            filtered = filtered.filter { element in
                let text = """
                    \(element.AXRole ?? "")
                    \(element.AXSubrole ?? "")
                    \(element.AXTitle ?? "")
                    \(element.AXDescription ?? "")
                    \(element.AXValue as? String ?? "")
                    """
                
                if currentCriteria.useRegex {
                    guard let regex = try? NSRegularExpression(pattern: currentCriteria.searchText) else {
                        return false
                    }
                    let range = NSRange(text.startIndex..., in: text)
                    return regex.firstMatch(in: text, range: range) != nil
                } else if currentCriteria.caseSensitive {
                    return text.contains(currentCriteria.searchText)
                } else {
                    return text.lowercased().contains(currentCriteria.searchText.lowercased())
                }
            }
        }
        
        resultsPublisher.send(filtered)
    }
    
    /// Update filter criteria
    func updateCriteria(_ criteria: FilterCriteria) {
        currentCriteria = criteria
    }
    
    // MARK: - Presets
    
    /// Save filter preset
    func savePreset(name: String, criteria: FilterCriteria) {
        let preset = FilterPreset(name: name, criteria: criteria)
        presets.append(preset)
        savePresets()
    }
    
    /// Delete filter preset
    func deletePreset(_ preset: FilterPreset) {
        presets.removeAll { $0.name == preset.name }
        savePresets()
    }
    
    /// Load filter preset
    func loadPreset(_ preset: FilterPreset) {
        currentCriteria = preset.criteria
    }
    
    /// Load presets from disk
    private func loadPresets() {
        guard let data = try? Data(contentsOf: presetsURL),
              let presets = try? PropertyListDecoder().decode([FilterPreset].self, from: data) else {
            return
        }
        self.presets = presets
    }
    
    /// Save presets to disk
    private func savePresets() {
        guard let data = try? PropertyListEncoder().encode(presets) else { return }
        try? data.write(to: presetsURL)
    }
    
    private var presetsURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("UI Browser 4")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("FilterPresets.plist")
    }
}