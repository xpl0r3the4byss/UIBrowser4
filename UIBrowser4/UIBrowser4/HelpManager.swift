import Cocoa

/// Manages help content and documentation
@MainActor
class HelpManager {
    // MARK: - Types
    
    /// Help topic structure
    struct HelpTopic: Codable {
        let id: String
        let title: String
        let content: String
        let keywords: [String]
        let relatedTopics: [String]
    }
    
    /// Help category
    struct HelpCategory: Codable {
        let id: String
        let title: String
        let topics: [HelpTopic]
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = HelpManager()
    
    /// Help categories
    private(set) var categories: [HelpCategory] = []
    
    /// Topic tooltips
    private var tooltips: [String: String] = [:]
    
    // MARK: - Initialization
    
    private init() {
        loadHelpContent()
        setupTooltips()
    }
    
    // MARK: - Help Content
    
    /// Load help content from bundle
    private func loadHelpContent() {
        guard let url = Bundle.main.url(forResource: "Help", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([HelpCategory].self, from: data) else {
            return
        }
        
        self.categories = categories
    }
    
    /// Setup common tooltips
    private func setupTooltips() {
        tooltips = [
            "browser.view": "Displays UI elements in a hierarchical browser view",
            "outline.view": "Shows UI elements in an expandable outline view",
            "list.view": "Presents UI elements in a flat list view",
            "script.generate": "Generate AppleScript code for the selected element",
            "script.run": "Execute the generated AppleScript",
            "script.save": "Save the current script for later use",
            "element.highlight": "Highlight the selected element in the target application",
            "element.track": "Track focus changes in the target application",
            "element.attributes": "View and inspect element attributes"
        ]
    }
    
    // MARK: - Help Access
    
    /// Get help topic by ID
    func topic(for id: String) -> HelpTopic? {
        for category in categories {
            if let topic = category.topics.first(where: { $0.id == id }) {
                return topic
            }
        }
        return nil
    }
    
    /// Search help topics
    func searchTopics(_ query: String) -> [HelpTopic] {
        let searchTerms = query.lowercased().split(separator: " ")
        
        return categories.flatMap { $0.topics }.filter { topic in
            let text = "\(topic.title) \(topic.content) \(topic.keywords.joined(separator: " "))".lowercased()
            return searchTerms.allSatisfy { term in
                text.contains(term)
            }
        }
    }
    
    /// Get tooltip for view
    func tooltip(for identifier: String) -> String? {
        return tooltips[identifier]
    }
    
    // MARK: - Help Display
    
    /// Show help window
    func showHelpWindow() {
        // Load help window from storyboard
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let windowController = storyboard.instantiateController(withIdentifier: "HelpWindow") as? NSWindowController {
            windowController.showWindow(nil)
        }
    }
    
    /// Show quick help for view
    func showQuickHelp(for view: NSView) {
        guard let identifier = view.identifier?.rawValue,
              let tooltip = tooltips[identifier] else {
            return
        }
        
        // Create and configure help popover
        let popover = NSPopover()
        popover.behavior = .transient
        
        let label = NSTextField(labelWithString: tooltip)
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.preferredMaxLayoutWidth = 200
        
        let padding: CGFloat = 8
        let container = NSView(frame: NSRect(x: 0, y: 0,
                                           width: label.fittingSize.width + padding * 2,
                                           height: label.fittingSize.height + padding * 2))
        container.addSubview(label)
        label.frame = NSRect(x: padding, y: padding,
                           width: label.fittingSize.width,
                           height: label.fittingSize.height)
        
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = container
        
        // Show popover
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
    }
}