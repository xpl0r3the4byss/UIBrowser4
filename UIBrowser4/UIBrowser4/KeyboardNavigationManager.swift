import Cocoa

/// Manager for handling keyboard navigation across all views
@MainActor
final class KeyboardNavigationManager {
    /// Shared instance
    static let shared = KeyboardNavigationManager()
    
    /// Navigation commands
    enum NavigationCommand {
        case moveUp
        case moveDown
        case moveLeft
        case moveRight
        case expandItem
        case collapseItem
        case selectItem
        case goToParent
        case goToFirstChild
        case goToLastChild
        case goToFirstSibling
        case goToLastSibling
        
        /// Get the command for a key event
        static func from(event: NSEvent) -> NavigationCommand? {
            switch event.keyCode {
            case 126: // Up arrow
                return event.modifierFlags.contains(.command) ? .goToParent : .moveUp
            case 125: // Down arrow
                return event.modifierFlags.contains(.command) ? .goToFirstChild : .moveDown
            case 123: // Left arrow
                return event.modifierFlags.contains(.command) ? .goToFirstSibling : 
                       event.modifierFlags.contains(.option) ? .collapseItem : .moveLeft
            case 124: // Right arrow
                return event.modifierFlags.contains(.command) ? .goToLastSibling :
                       event.modifierFlags.contains(.option) ? .expandItem : .moveRight
            case 36: // Return
                return .selectItem
            default:
                return nil
            }
        }
    }
    
    /// Handle keyboard event for a view
    func handleKeyEvent(_ event: NSEvent, in view: NSView) async throws {
        guard let command = NavigationCommand.from(event: event) else { return }
        
        switch view {
        case let browser as NSBrowser:
            try await handleBrowserNavigation(command, in: browser)
            
        case let outline as NSOutlineView:
            try await handleOutlineNavigation(command, in: outline)
            
        case let table as NSTableView:
            try await handleTableNavigation(command, in: table)
            
        default:
            break
        }
    }
    
    /// Handle browser navigation
    private func handleBrowserNavigation(_ command: NavigationCommand, in browser: NSBrowser) async throws {
        let dataSource = ElementDataModel.sharedInstance
        
        switch command {
        case .moveUp:
            let col = browser.selectedColumn
            let row = max(0, browser.selectedRow(inColumn: col) - 1)
            browser.selectRow(row, inColumn: col)
            
        case .moveDown:
            let col = browser.selectedColumn
            let maxRow = browser.numberOfRows(inColumn: col) - 1
            let row = min(maxRow, browser.selectedRow(inColumn: col) + 1)
            browser.selectRow(row, inColumn: col)
            
        case .moveLeft:
            let col = max(0, browser.selectedColumn - 1)
            browser.selectRow(browser.selectedRow(inColumn: col), inColumn: col)
            
        case .moveRight:
            if browser.selectedColumn < browser.lastColumn {
                let col = browser.selectedColumn + 1
                browser.selectRow(browser.selectedRow(inColumn: col), inColumn: col)
            }
            
        case .goToParent:
            if browser.selectedColumn > 0 {
                let col = browser.selectedColumn - 1
                browser.selectRow(browser.selectedRow(inColumn: col), inColumn: col)
            }
            
        case .goToFirstChild:
            if browser.selectedColumn < browser.lastColumn {
                let col = browser.selectedColumn + 1
                browser.selectRow(0, inColumn: col)
            }
            
        case .goToLastChild:
            if browser.selectedColumn < browser.lastColumn {
                let col = browser.selectedColumn + 1
                let maxRow = browser.numberOfRows(inColumn: col) - 1
                browser.selectRow(maxRow, inColumn: col)
            }
            
        case .goToFirstSibling:
            let col = browser.selectedColumn
            browser.selectRow(0, inColumn: col)
            
        case .goToLastSibling:
            let col = browser.selectedColumn
            let maxRow = browser.numberOfRows(inColumn: col) - 1
            browser.selectRow(maxRow, inColumn: col)
            
        case .expandItem:
            if browser.selectedColumn < browser.lastColumn {
                let col = browser.selectedColumn + 1
                browser.selectRow(browser.selectedRow(inColumn: col), inColumn: col)
            }
            
        case .collapseItem:
            if browser.selectedColumn > 0 {
                let col = browser.selectedColumn - 1
                browser.selectRow(browser.selectedRow(inColumn: col), inColumn: col)
            }
            
        case .selectItem:
            if let node = browser.selectedCell() {
                try await dataSource.updateDataModelForCurrentElementAt(
                    level: browser.selectedColumn,
                    index: browser.selectedRow(inColumn: browser.selectedColumn)
                )
            }
        }
    }
    
    /// Handle outline navigation
    private func handleOutlineNavigation(_ command: NavigationCommand, in outline: NSOutlineView) async throws {
        let dataSource = ElementDataModel.sharedInstance
        
        switch command {
        case .moveUp:
            let row = max(0, outline.selectedRow - 1)
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
        case .moveDown:
            let maxRow = outline.numberOfRows - 1
            let row = min(maxRow, outline.selectedRow + 1)
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
        case .goToParent:
            if let item = outline.item(atRow: outline.selectedRow),
               let parent = outline.parent(forItem: item) {
                let parentRow = outline.row(forItem: parent)
                outline.selectRowIndexes(IndexSet(integer: parentRow), byExtendingSelection: false)
            }
            
        case .goToFirstChild:
            if let item = outline.item(atRow: outline.selectedRow),
               outline.isExpandable(item) {
                outline.expandItem(item)
                if let firstChild = outline.child(0, ofItem: item) {
                    let childRow = outline.row(forItem: firstChild)
                    outline.selectRowIndexes(IndexSet(integer: childRow), byExtendingSelection: false)
                }
            }
            
        case .goToLastChild:
            if let item = outline.item(atRow: outline.selectedRow),
               outline.isExpandable(item) {
                outline.expandItem(item)
                let lastChildIndex = outline.numberOfChildren(ofItem: item) - 1
                if let lastChild = outline.child(lastChildIndex, ofItem: item) {
                    let childRow = outline.row(forItem: lastChild)
                    outline.selectRowIndexes(IndexSet(integer: childRow), byExtendingSelection: false)
                }
            }
            
        case .goToFirstSibling:
            if let item = outline.item(atRow: outline.selectedRow),
               let parent = outline.parent(forItem: item),
               let firstSibling = outline.child(0, ofItem: parent) {
                let siblingRow = outline.row(forItem: firstSibling)
                outline.selectRowIndexes(IndexSet(integer: siblingRow), byExtendingSelection: false)
            }
            
        case .goToLastSibling:
            if let item = outline.item(atRow: outline.selectedRow),
               let parent = outline.parent(forItem: item) {
                let lastSiblingIndex = outline.numberOfChildren(ofItem: parent) - 1
                if let lastSibling = outline.child(lastSiblingIndex, ofItem: parent) {
                    let siblingRow = outline.row(forItem: lastSibling)
                    outline.selectRowIndexes(IndexSet(integer: siblingRow), byExtendingSelection: false)
                }
            }
            
        case .expandItem:
            if let item = outline.item(atRow: outline.selectedRow),
               outline.isExpandable(item) {
                outline.expandItem(item)
            }
            
        case .collapseItem:
            if let item = outline.item(atRow: outline.selectedRow),
               outline.isExpandable(item) {
                outline.collapseItem(item)
            }
            
        case .selectItem:
            if let item = outline.item(atRow: outline.selectedRow) as? ElementDataModel.ElementNodeInfo {
                let path = dataSource.indexPath(ofNode: item)
                let level = path.length - 1
                let index = path.index(atPosition: level)
                try await dataSource.updateDataModelForCurrentElementAt(level: level, index: index)
            }
            
        default:
            break
        }
    }
    
    /// Handle table navigation
    private func handleTableNavigation(_ command: NavigationCommand, in table: NSTableView) async throws {
        let dataSource = ElementDataModel.sharedInstance
        
        switch command {
        case .moveUp:
            let row = max(0, table.selectedRow - 1)
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
        case .moveDown:
            let maxRow = table.numberOfRows - 1
            let row = min(maxRow, table.selectedRow + 1)
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
        case .goToFirstSibling:
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            
        case .goToLastSibling:
            let maxRow = table.numberOfRows - 1
            table.selectRowIndexes(IndexSet(integer: maxRow), byExtendingSelection: false)
            
        case .selectItem:
            let currentPath = dataSource.currentElementIndexPath!
            let selectedLevel = currentPath.length - 1
            try await dataSource.updateDataModelForCurrentElementAt(
                level: selectedLevel,
                index: table.selectedRow
            )
            
        default:
            break
        }
    }
}