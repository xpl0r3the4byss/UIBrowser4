import Foundation

/// Manages data export and import
@MainActor
class DataManager {
    // MARK: - Types
    
    /// Exportable data package
    struct DataPackage: Codable {
        let version: String = "1.0.0"
        let timestamp: Date = Date()
        let theme: ThemeManager.ThemeConfig
        let scripts: [ScriptWindowManager.SavedScript]
        
        var fileName: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let date = formatter.string(from: timestamp)
            return "UIBrowser4-Backup-\(date).json"
        }
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = DataManager()
    
    // MARK: - Export
    
    /// Export all application data
    func exportData() throws -> Data {
        let package = DataPackage(
            theme: ThemeManager.shared.config,
            scripts: ScriptWindowManager.shared.savedScriptsPublisher.value
        )
        
        return try JSONEncoder().encode(package)
    }
    
    /// Import application data
    func importData(_ data: Data) throws {
        let package = try JSONDecoder().decode(DataPackage.self, from: data)
        
        // Version check
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        guard isVersionCompatible(package.version, with: currentVersion) else {
            throw DataError.incompatibleVersion
        }
        
        // Update theme config
        ThemeManager.shared.config = package.theme
        
        // Import scripts
        for script in package.scripts {
            try ScriptWindowManager.shared.importScript(script)
        }
    }
    
    // MARK: - File Operations
    
    /// Save data package to file
    func saveToFile(_ url: URL) throws {
        let data = try exportData()
        try data.write(to: url)
    }
    
    /// Load data package from file
    func loadFromFile(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        try importData(data)
    }
    
    // MARK: - Helpers
    
    private func isVersionCompatible(_ packageVersion: String, with currentVersion: String) -> Bool {
        let package = packageVersion.split(separator: ".").compactMap { Int($0) }
        let current = currentVersion.split(separator: ".").compactMap { Int($0) }
        
        // Major version must match
        guard package.count > 0, current.count > 0, package[0] == current[0] else {
            return false
        }
        
        return true
    }
}

// MARK: - Supporting Types

enum DataError: LocalizedError {
    case incompatibleVersion
    
    var errorDescription: String? {
        switch self {
        case .incompatibleVersion:
            return "The backup file version is not compatible with this version of UI Browser"
        }
    }
}