import Cocoa

/// Table view with keyboard navigation support
class KeyboardNavigableTableView: NSTableView {
    override func keyDown(with event: NSEvent) {
        Task {
            do {
                await KeyboardNavigationManager.shared.handleKeyEvent(event, in: self)
            } catch {
                // Present error to user
                let alert = NSAlert()
                alert.messageText = "Navigation Error"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}