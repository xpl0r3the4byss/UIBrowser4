import Cocoa
import Combine

/// Manages element visualization and highlighting effects
@MainActor
final class ElementVisualizationManager {
    // MARK: - Types
    
    /// Visualization style
    enum Style {
        case standard
        case focus
        case warning
        case error
        case custom(ElementHighlightWindow.Style)
        
        var highlightStyle: ElementHighlightWindow.Style {
            switch self {
            case .standard:
                return .standard
            case .focus:
                return .focus
            case .warning:
                return .warning
            case .error:
                return .error
            case .custom(let style):
                return style
            }
        }
    }
    
    /// Highlight pattern
    enum Pattern {
        case solid
        case pulse(count: Int)
        case flash(interval: TimeInterval)
        case fade(duration: TimeInterval)
        case path(elements: [AccessibleElement])
    }
    
    /// Visualization options
    struct Options {
        var style: Style = .standard
        var pattern: Pattern = .solid
        var duration: TimeInterval = 2.0
        var fadeOut: Bool = true
        var showBadge: Bool = false
        var badgeText: String?
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementVisualizationManager()
    
    /// Active highlight windows
    private var highlightWindows: [AccessibleElement: ElementHighlightWindow] = [:]
    
    /// Pattern tasks
    private var patternTasks: [AccessibleElement: Task<Void, Never>] = [:]
    
    /// Badge windows
    private var badgeWindows: [AccessibleElement: NSWindow] = [:]
    
    /// Publishers
    let visualizationStartedPublisher = PassthroughSubject<AccessibleElement, Never>()
    let visualizationEndedPublisher = PassthroughSubject<AccessibleElement, Never>()
    
    // MARK: - Visualization Control
    
    /// Show visualization for element
    func showVisualization(
        for element: AccessibleElement,
        options: Options = Options()
    ) async {
        // Hide existing visualization
        hideVisualization(for: element)
        
        // Get element frame
        guard let position = element.AXPosition as? NSPoint,
              let size = element.AXSize as? NSSize else {
            return
        }
        
        let frame = NSRect(origin: position, size: size)
        
        // Create highlight window
        let window = ElementHighlightWindow(style: options.style.highlightStyle)
        highlightWindows[element] = window
        
        // Show highlight
        window.showHighlight(for: frame)
        
        // Show badge if needed
        if options.showBadge {
            showBadge(for: element, text: options.badgeText, frame: frame)
        }
        
        // Apply pattern
        applyPattern(options.pattern, to: element, window: window)
        
        // Notify start
        visualizationStartedPublisher.send(element)
        
        // Auto-hide if needed
        if options.duration > 0 {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(options.duration * 1_000_000_000))
                if options.fadeOut {
                    await hideVisualization(for: element, animated: true)
                } else {
                    await hideVisualization(for: element)
                }
            }
        }
    }
    
    /// Hide visualization for element
    func hideVisualization(
        for element: AccessibleElement,
        animated: Bool = false
    ) async {
        // Cancel pattern task
        patternTasks[element]?.cancel()
        patternTasks[element] = nil
        
        // Hide highlight
        highlightWindows[element]?.hideHighlight(animated: animated)
        highlightWindows[element] = nil
        
        // Hide badge
        badgeWindows[element]?.close()
        badgeWindows[element] = nil
        
        // Notify end
        visualizationEndedPublisher.send(element)
    }
    
    /// Hide all visualizations
    func hideAllVisualizations(animated: Bool = false) async {
        for element in highlightWindows.keys {
            await hideVisualization(for: element, animated: animated)
        }
    }
    
    // MARK: - Pattern Application
    
    private func applyPattern(
        _ pattern: Pattern,
        to element: AccessibleElement,
        window: ElementHighlightWindow
    ) {
        // Cancel existing pattern
        patternTasks[element]?.cancel()
        
        // Create pattern task
        let task = Task { [weak self] in
            do {
                switch pattern {
                case .solid:
                    break // No animation needed
                    
                case .pulse(let count):
                    for _ in 0..<count {
                        guard !Task.isCancelled else { break }
                        
                        // Fade out
                        try await self?.animate {
                            window.alphaValue = 0.2
                        }
                        
                        // Fade in
                        try await self?.animate {
                            window.alphaValue = 1.0
                        }
                    }
                    
                case .flash(let interval):
                    while !Task.isCancelled {
                        window.isHidden = true
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                        window.isHidden = false
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                    
                case .fade(let duration):
                    try await self?.animate(duration: duration) {
                        window.alphaValue = 0
                    }
                    
                case .path(let elements):
                    for pathElement in elements {
                        guard !Task.isCancelled else { break }
                        
                        // Show highlight
                        await self?.showVisualization(
                            for: pathElement,
                            options: Options(
                                style: .focus,
                                pattern: .solid,
                                duration: 0.5
                            )
                        )
                        
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    }
                }
            } catch {
                if !error.isCancellationError {
                    print("Pattern error: \(error)")
                }
            }
        }
        
        patternTasks[element] = task
    }
    
    // MARK: - Badge Management
    
    private func showBadge(
        for element: AccessibleElement,
        text: String?,
        frame: NSRect
    ) {
        // Create badge window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 50, height: 24),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        
        // Create badge view
        let badge = BadgeView(
            text: text ?? "\(frame.size.width.rounded())×\(frame.size.height.rounded())"
        )
        window.contentView = badge
        
        // Position badge
        var badgeFrame = window.frame
        badgeFrame.origin = NSPoint(
            x: frame.maxX - badgeFrame.width,
            y: frame.maxY
        )
        window.setFrame(badgeFrame, display: true)
        
        // Show badge
        window.orderFront(nil)
        badgeWindows[element] = window
    }
    
    // MARK: - Animation Helpers
    
    private func animate(
        duration: TimeInterval = 0.2,
        animations: @escaping () -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                animations()
            }, completionHandler: {
                continuation.resume()
            })
        }
    }
}

// MARK: - Supporting Views

/// Badge view for element information
private class BadgeView: NSView {
    /// Badge text
    private let text: String
    
    init(text: String) {
        self.text = text
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        self.text = ""
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw background
        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        NSColor.controlBackgroundColor.withAlphaComponent(0.8).setFill()
        path.fill()
        
        // Draw text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.textColor
        ]
        
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        
        string.draw(at: point)
    }
}

// MARK: - Error Extensions

private extension Error {
    var isCancellationError: Bool {
        self is CancellationError
    }
}