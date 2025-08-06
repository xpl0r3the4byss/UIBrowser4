import Cocoa

/// Browser view with keyboard navigation support
class KeyboardNavigableBrowser: NSBrowser {
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