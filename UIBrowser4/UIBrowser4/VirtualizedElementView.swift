import Cocoa

/// Protocol for virtualized element views
protocol VirtualizedElementView: NSView {
    /// Current visibility range
    var visibleRange: Range<Int> { get }
    
    /// Total number of elements
    var totalElements: Int { get }
    
    /// Update visible range
    func updateVisibleRange(_ range: Range<Int>)
    
    /// Prefetch elements in range
    func prefetchRange(_ range: Range<Int>)
}

/// Base class for virtualized element views
class BaseVirtualizedView: NSView {
    // MARK: - Properties
    
    /// Virtualization configuration
    struct Config {
        /// Number of elements to buffer before visible range
        var leadingBufferCount: Int = 50
        
        /// Number of elements to buffer after visible range
        var trailingBufferCount: Int = 50
        
        /// Prefetch window size
        var prefetchWindow: Int = 100
        
        /// Minimum time between updates
        var updateThrottle: TimeInterval = 0.1
    }
    
    /// Current configuration
    var config: Config = Config()
    
    /// Current visible range
    private(set) var visibleRange: Range<Int> = 0..<0
    
    /// Currently rendered range (including buffers)
    private(set) var renderedRange: Range<Int> = 0..<0
    
    /// Last update timestamp
    private var lastUpdate: Date = .distantPast
    
    /// Scroll observation task
    private var scrollObserver: Task<Void, Never>?
    
    // MARK: - Initialization
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupScrollObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollObserver()
    }
    
    deinit {
        scrollObserver?.cancel()
    }
    
    // MARK: - Scroll Observation
    
    private func setupScrollObserver() {
        scrollObserver = Task { [weak self] in
            while !Task.isCancelled {
                // Check if update needed
                if let self = self,
                   let scrollView = self.enclosingScrollView,
                   Date().timeIntervalSince(self.lastUpdate) >= self.config.updateThrottle {
                    
                    // Calculate visible range
                    let visibleRect = scrollView.documentVisibleRect
                    let newRange = self.calculateVisibleRange(for: visibleRect)
                    
                    if newRange != self.visibleRange {
                        await self.updateRanges(visibleRange: newRange)
                    }
                }
                
                // Wait for next frame
                try? await Task.sleep(nanoseconds: 16_666_667) // ~60fps
            }
        }
    }
    
    // MARK: - Range Management
    
    /// Calculate visible range for rect
    func calculateVisibleRange(for rect: NSRect) -> Range<Int> {
        fatalError("Must be implemented by subclass")
    }
    
    /// Update visible and rendered ranges
    @MainActor
    private func updateRanges(visibleRange: Range<Int>) {
        // Update visible range
        self.visibleRange = visibleRange
        
        // Calculate rendered range with buffers
        let renderedStart = max(0, visibleRange.lowerBound - config.leadingBufferCount)
        let renderedEnd = min(totalElements, visibleRange.upperBound + config.trailingBufferCount)
        let newRenderedRange = renderedStart..<renderedEnd
        
        // Update if changed
        if newRenderedRange != renderedRange {
            renderedRange = newRenderedRange
            updateRenderedElements()
        }
        
        // Calculate prefetch range
        let prefetchStart = max(0, renderedRange.upperBound)
        let prefetchEnd = min(totalElements, prefetchStart + config.prefetchWindow)
        let prefetchRange = prefetchStart..<prefetchEnd
        
        // Queue prefetch
        if !prefetchRange.isEmpty {
            queuePrefetch(for: prefetchRange)
        }
        
        lastUpdate = Date()
    }
    
    /// Update rendered elements
    @MainActor
    func updateRenderedElements() {
        fatalError("Must be implemented by subclass")
    }
    
    /// Queue range for prefetching
    private func queuePrefetch(for range: Range<Int>) {
        ElementBatchLoader.shared.queueBatchLoad(
            range: range,
            priority: .prefetch
        )
    }
    
    /// Total number of elements
    var totalElements: Int {
        fatalError("Must be implemented by subclass")
    }
}

// MARK: - Virtualized Table View

/// Table view with element virtualization
class VirtualizedTableView: NSTableView, VirtualizedElementView {
    // MARK: - Properties
    
    private var virtualizedView: BaseVirtualizedView?
    
    // MARK: - VirtualizedElementView
    
    var visibleRange: Range<Int> {
        guard let view = virtualizedView else {
            return 0..<0
        }
        return view.visibleRange
    }
    
    var totalElements: Int {
        return numberOfRows
    }
    
    func updateVisibleRange(_ range: Range<Int>) {
        reloadData(forRowIndexes: IndexSet(integersIn: range),
                  columnIndexes: IndexSet(0..<numberOfColumns))
    }
    
    func prefetchRange(_ range: Range<Int>) {
        // Implemented by data source
    }
    
    // MARK: - Setup
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if virtualizedView == nil {
            setupVirtualization()
        }
    }
    
    private func setupVirtualization() {
        let view = BaseVirtualizedView(frame: bounds)
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        virtualizedView = view
    }
}

// MARK: - Virtualized Outline View

/// Outline view with element virtualization
class VirtualizedOutlineView: NSOutlineView, VirtualizedElementView {
    // MARK: - Properties
    
    private var virtualizedView: BaseVirtualizedView?
    
    // MARK: - VirtualizedElementView
    
    var visibleRange: Range<Int> {
        guard let view = virtualizedView else {
            return 0..<0
        }
        return view.visibleRange
    }
    
    var totalElements: Int {
        return numberOfRows
    }
    
    func updateVisibleRange(_ range: Range<Int>) {
        reloadData(forRowIndexes: IndexSet(integersIn: range),
                  columnIndexes: IndexSet(0..<numberOfColumns))
    }
    
    func prefetchRange(_ range: Range<Int>) {
        // Implemented by data source
    }
    
    // MARK: - Setup
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if virtualizedView == nil {
            setupVirtualization()
        }
    }
    
    private func setupVirtualization() {
        let view = BaseVirtualizedView(frame: bounds)
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        virtualizedView = view
    }
}