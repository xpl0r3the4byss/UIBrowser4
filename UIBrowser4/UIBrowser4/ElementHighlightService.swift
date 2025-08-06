import Cocoa

/// Service for highlighting accessibility elements in the UI
@MainActor
class ElementHighlightService {
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementHighlightService()
    
    /// Current highlight window
    private var highlightWindow: NSWindow?
    
    /// Timer for auto-hiding highlight
    private var hideTimer: Timer?
    
    /// Currently tracked element
    private var trackedElement: AccessibleElement?
    
    /// Focus observation task
    private var focusObservationTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    /// Highlight an element temporarily
    func highlightElement(_ element: AccessibleElement, duration: TimeInterval = 2.0) {
        guard let position = element.AXPosition as? NSPoint,
              let size = element.AXSize as? NSSize else {
            return
        }
        
        let frame = NSRect(origin: position, size: size)
        showHighlight(frame: frame)
        
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hideHighlight()
        }
    }
    
    /// Start tracking focus changes for an element and its descendants
    func startTrackingFocus(for element: AccessibleElement) {
        stopTrackingFocus()
        
        trackedElement = element
        focusObservationTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Create observation
            for await notification in element.observeNotification(.focusedUIElementChanged) {
                if let focusedElement = notification.element {
                    await self.highlightElement(focusedElement)
                }
            }
        }
    }
    
    /// Stop tracking focus changes
    func stopTrackingFocus() {
        focusObservationTask?.cancel()
        focusObservationTask = nil
        trackedElement = nil
        hideHighlight()
    }
    
    // MARK: - Private Methods
    
    private func showHighlight(frame: NSRect) {
        if highlightWindow == nil {
            highlightWindow = NSWindow(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            highlightWindow?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2)
            highlightWindow?.isOpaque = false
            highlightWindow?.hasShadow = false
            highlightWindow?.level = .floating
            highlightWindow?.ignoresMouseEvents = true
        }
        
        highlightWindow?.setFrame(frame, display: true)
        highlightWindow?.orderFront(nil)
    }
    
    private func hideHighlight() {
        highlightWindow?.orderOut(nil)
        hideTimer?.invalidate()
        hideTimer = nil
    }
}