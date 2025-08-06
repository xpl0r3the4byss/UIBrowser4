import Cocoa
import WebKit

/// View controller for displaying help content
class HelpViewController: NSViewController {
    // MARK: - Properties
    
    private var selectedCategory: HelpManager.HelpCategory?
    private var selectedTopic: HelpManager.HelpTopic?
    private var searchResults: [HelpManager.HelpTopic] = []
    private var isSearching = false
    
    // MARK: - Outlets
    
    @IBOutlet weak var sidebarOutlineView: NSOutlineView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var contentWebView: WKWebView!
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var forwardButton: NSButton!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadInitialContent()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Configure outline view
        sidebarOutlineView.delegate = self
        sidebarOutlineView.dataSource = self
        
        // Configure search field
        searchField.delegate = self
        
        // Configure web view
        contentWebView.navigationDelegate = self
        
        // Configure navigation buttons
        updateNavigationButtons()
    }
    
    private func loadInitialContent() {
        sidebarOutlineView.reloadData()
        
        // Load first topic if available
        if let firstCategory = HelpManager.shared.categories.first,
           let firstTopic = firstCategory.topics.first {
            selectedCategory = firstCategory
            showTopic(firstTopic)
        }
    }
    
    // MARK: - Navigation
    
    private func showTopic(_ topic: HelpManager.HelpTopic) {
        selectedTopic = topic
        
        // Convert markdown to HTML
        let htmlContent = convertToHTML(topic)
        contentWebView.loadHTMLString(htmlContent, baseURL: nil)
        
        // Update outline selection
        if !isSearching {
            let categoryRow = HelpManager.shared.categories.firstIndex(where: { $0.id == selectedCategory?.id })
            if let categoryRow = categoryRow {
                sidebarOutlineView.expandItem(nil, expandChildren: true)
                sidebarOutlineView.selectRowIndexes(IndexSet(integer: categoryRow), byExtendingSelection: false)
            }
        }
    }
    
    private func updateNavigationButtons() {
        backButton.isEnabled = contentWebView.canGoBack
        forwardButton.isEnabled = contentWebView.canGoForward
    }
    
    // MARK: - Actions
    
    @IBAction func goBack(_ sender: Any) {
        contentWebView.goBack()
    }
    
    @IBAction func goForward(_ sender: Any) {
        contentWebView.goForward()
    }
    
    @IBAction func showHome(_ sender: Any) {
        if let firstCategory = HelpManager.shared.categories.first,
           let firstTopic = firstCategory.topics.first {
            selectedCategory = firstCategory
            showTopic(firstTopic)
        }
    }
    
    // MARK: - Search
    
    private func performSearch(_ query: String) {
        if query.isEmpty {
            isSearching = false
            searchResults = []
        } else {
            isSearching = true
            searchResults = HelpManager.shared.searchTopics(query)
        }
        sidebarOutlineView.reloadData()
    }
    
    // MARK: - Content Formatting
    
    private func convertToHTML(_ topic: HelpManager.HelpTopic) -> String {
        // Basic HTML template
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    line-height: 1.5;
                    margin: 20px;
                    color: \(isDarkMode ? "#FFFFFF" : "#000000");
                    background: \(isDarkMode ? "#1E1E1E" : "#FFFFFF");
                }
                h1 { font-size: 24px; margin-bottom: 16px; }
                h2 { font-size: 20px; margin: 24px 0 12px 0; }
                p { margin: 12px 0; }
                code { font-family: SF Mono, monospace; background: \(isDarkMode ? "#2D2D2D" : "#F5F5F5"); padding: 2px 4px; border-radius: 4px; }
                .related { margin-top: 32px; padding-top: 16px; border-top: 1px solid \(isDarkMode ? "#3E3E3E" : "#E5E5E5"); }
            </style>
        </head>
        <body>
            <h1>\(topic.title)</h1>
            \(topic.content)
            
            <div class="related">
                <h2>Related Topics</h2>
                <ul>
                \(relatedTopicsHTML(topic))
                </ul>
            </div>
        </body>
        </html>
        """
    }
    
    private func relatedTopicsHTML(_ topic: HelpManager.HelpTopic) -> String {
        return topic.relatedTopics.compactMap { topicId in
            if let related = HelpManager.shared.topic(for: topicId) {
                return "<li><a href=\"uitopic://\(topicId)\">\(related.title)</a></li>"
            }
            return nil
        }.joined(separator: "\n")
    }
    
    private var isDarkMode: Bool {
        return view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - NSOutlineViewDataSource

extension HelpViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if isSearching {
            return item == nil ? searchResults.count : 0
        } else {
            if item == nil {
                return HelpManager.shared.categories.count
            } else if let category = item as? HelpManager.HelpCategory {
                return category.topics.count
            }
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if isSearching {
            return searchResults[index]
        } else {
            if item == nil {
                return HelpManager.shared.categories[index]
            } else if let category = item as? HelpManager.HelpCategory {
                return category.topics[index]
            }
            fatalError("Invalid outline view state")
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if isSearching {
            return false
        } else {
            return item is HelpManager.HelpCategory
        }
    }
}

// MARK: - NSOutlineViewDelegate

extension HelpViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
        
        if let category = item as? HelpManager.HelpCategory {
            view?.textField?.stringValue = category.title
            view?.textField?.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        } else if let topic = item as? HelpManager.HelpTopic {
            view?.textField?.stringValue = topic.title
            view?.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
        }
        
        return view
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        
        let selectedItem = outlineView.item(atRow: outlineView.selectedRow)
        if let topic = selectedItem as? HelpManager.HelpTopic {
            if let category = outlineView.parent(forItem: topic) as? HelpManager.HelpCategory {
                selectedCategory = category
            }
            showTopic(topic)
        }
    }
}

// MARK: - NSSearchFieldDelegate

extension HelpViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        performSearch(searchField.stringValue)
    }
}

// MARK: - WKNavigationDelegate

extension HelpViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           url.scheme == "uitopic",
           let topicId = url.host,
           let topic = HelpManager.shared.topic(for: topicId) {
            showTopic(topic)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateNavigationButtons()
    }
}