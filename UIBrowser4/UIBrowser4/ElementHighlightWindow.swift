import Cocoa

/// Window for highlighting accessibility elements
class ElementHighlightWindow: NSWindow {
    // MARK: - Types
    
    /// Highlight style
    struct Style {
        /// Fill color
        var fillColor: NSColor
        
        /// Border color
        var borderColor: NSColor
        
        /// Border width
        var borderWidth: CGFloat
        
        /// Corner radius
        var cornerRadius: CGFloat
        
        /// Animation duration
        var animationDuration: TimeInterval
        
        /// Default styles
        static var standard: Style {
            Style(
                fillColor: NSColor.systemBlue.withAlphaComponent(0.2),
                borderColor: NSColor.systemBlue.withAlphaComponent(0.5),
                borderWidth: 2.0,
                cornerRadius: 4.0,
                animationDuration: 0.2
            )
        }
        
        static var focus: Style {
            Style(
                fillColor: NSColor.systemGreen.withAlphaComponent(0.2),
                borderColor: NSColor.systemGreen.withAlphaComponent(0.5),
                borderWidth: 2.0,
                cornerRadius: 4.0,
                animationDuration: 0.15
            )
        }
        
        static var warning: Style {
            Style(
                fillColor: NSColor.systemYellow.withAlphaComponent(0.2),
                borderColor: NSColor.systemYellow.withAlphaComponent(0.5),
                borderWidth: 2.0,
                cornerRadius: 4.0,
                animationDuration: 0.3
            )
        }
        
        static var error: Style {
            Style(
                fillColor: NSColor.systemRed.withAlphaComponent(0.2),
                borderColor: NSColor.systemRed.withAlphaComponent(0.5),
                borderWidth: 2.0,
                cornerRadius: 4.0,
                animationDuration: 0.3
            )
        }
    }
    
    // MARK: - Properties
    
    /// Current style
    private var style: Style
    
    /// Content view
    private var highlightView: HighlightView!
    
    // MARK: - Initialization
    
    init(style: Style = .standard) {
        self.style = style
        
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        // Configure window
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        
        // Set collectionBehavior to work with fullscreen apps
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    private func setupView() {
        // Create highlight view
        highlightView = HighlightView(style: style)
        contentView = highlightView
    }
    
    // MARK: - Highlighting
    
    /// Show highlight for frame
    func showHighlight(for frame: NSRect, animated: Bool = true) {
        // Convert frame to screen coordinates if needed
        let screenFrame = frame
        
        // Update window frame
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = style.animationDuration
                self.animator().setFrame(screenFrame, display: true)
            }
        } else {
            setFrame(screenFrame, display: true)
        }
        
        // Show window
        orderFront(nil)
    }
    
    /// Hide highlight
    func hideHighlight(animated: Bool = true) {
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = style.animationDuration
                self.animator().alphaValue = 0
            } completionHandler: {
                self.orderOut(nil)
                self.alphaValue = 1
            }
        } else {
            orderOut(nil)
        }
    }
    
    /// Update style
    func updateStyle(_ newStyle: Style, animated: Bool = true) {
        style = newStyle
        highlightView.updateStyle(newStyle, animated: animated)
    }
}

/// Custom view for highlight drawing
private class HighlightView: NSView {
    // MARK: - Properties
    
    /// Current style
    private var style: ElementHighlightWindow.Style
    
    // MARK: - Initialization
    
    init(style: ElementHighlightWindow.Style) {
        self.style = style
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.style = .standard
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Create path
        let path = NSBezierPath(roundedRect: bounds, xRadius: style.cornerRadius, yRadius: style.cornerRadius)
        
        // Fill
        style.fillColor.setFill()
        path.fill()
        
        // Stroke
        style.borderColor.setStroke()
        path.lineWidth = style.borderWidth
        path.stroke()
    }
    
    // MARK: - Style Updates
    
    func updateStyle(_ newStyle: ElementHighlightWindow.Style, animated: Bool) {
        let oldStyle = style
        style = newStyle
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = newStyle.animationDuration
                
                // Animate fill color
                let animation = CABasicAnimation(keyPath: "backgroundColor")
                animation.fromValue = oldStyle.fillColor.cgColor
                animation.toValue = newStyle.fillColor.cgColor
                layer?.add(animation, forKey: "fillColor")
                
                // Animate border color
                let borderAnimation = CABasicAnimation(keyPath: "borderColor")
                borderAnimation.fromValue = oldStyle.borderColor.cgColor
                borderAnimation.toValue = newStyle.borderColor.cgColor
                layer?.add(borderAnimation, forKey: "borderColor")
                
                // Animate border width
                let widthAnimation = CABasicAnimation(keyPath: "borderWidth")
                widthAnimation.fromValue = oldStyle.borderWidth
                widthAnimation.toValue = newStyle.borderWidth
                layer?.add(widthAnimation, forKey: "borderWidth")
            }
        }
        
        needsDisplay = true
    }
}