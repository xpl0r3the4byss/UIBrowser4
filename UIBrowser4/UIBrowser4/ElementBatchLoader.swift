import Foundation

/// Manages efficient batch loading of accessibility elements
@MainActor
final class ElementBatchLoader {
    // MARK: - Types
    
    /// Batch loading configuration
    struct Config {
        /// Initial batch size
        var initialBatchSize: Int = 50
        
        /// Background batch size
        var backgroundBatchSize: Int = 20
        
        /// Prefetch window size
        var prefetchWindow: Int = 100
        
        /// Loading priority levels
        enum Priority: Int {
            case visible = 3
            case nearVisible = 2
            case background = 1
            case prefetch = 0
        }
    }
    
    /// Loading state for a batch
    private struct BatchState {
        var startIndex: Int
        var endIndex: Int
        var priority: Config.Priority
        var isLoading: Bool = false
        var retryCount: Int = 0
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementBatchLoader()
    
    /// Loader configuration
    private var config: Config
    
    /// Active loading operations
    private var activeBatches: [BatchState] = []
    
    /// Loading queue
    private var loadingQueue: [(range: Range<Int>, priority: Config.Priority)] = []
    
    /// Background loading task
    private var backgroundTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init(config: Config = Config()) {
        self.config = config
    }
    
    // MARK: - Batch Loading
    
    /// Load initial batch of elements
    func loadInitialBatch(
        at index: Int,
        provider: @escaping (Int) async throws -> AccessibleElement
    ) async throws -> [AccessibleElement] {
        let range = max(0, index - config.initialBatchSize/2)..<(index + config.initialBatchSize/2)
        return try await loadBatch(range: range, priority: .visible, provider: provider)
    }
    
    /// Queue batch loading request
    func queueBatchLoad(
        range: Range<Int>,
        priority: Config.Priority = .background
    ) {
        loadingQueue.append((range, priority))
        sortLoadingQueue()
        
        // Start background loading if needed
        if backgroundTask == nil {
            startBackgroundLoading()
        }
    }
    
    /// Load batch of elements
    private func loadBatch(
        range: Range<Int>,
        priority: Config.Priority,
        provider: @escaping (Int) async throws -> AccessibleElement
    ) async throws -> [AccessibleElement] {
        var elements: [AccessibleElement] = []
        var errors: [(index: Int, error: Error)] = []
        
        // Create batch state
        let batch = BatchState(
            startIndex: range.lowerBound,
            endIndex: range.upperBound,
            priority: priority
        )
        activeBatches.append(batch)
        
        defer {
            activeBatches.removeAll { $0.startIndex == batch.startIndex }
        }
        
        // Load elements in parallel
        try await withThrowingTaskGroup(of: (Int, AccessibleElement).self) { group in
            // Add load tasks
            for index in range {
                group.addTask {
                    let element = try await provider(index)
                    return (index, element)
                }
            }
            
            // Process results
            while let result = try await group.next() {
                let (index, element) = result
                
                // Cache element
                if let attributes = try? await element.allAttributes() {
                    ElementCache.shared.cacheAttributes(attributes, for: element)
                }
                
                // Store element
                elements.append(element)
                
                // Queue prefetch for children
                if let children = try? await element.children {
                    for child in children {
                        ElementCache.shared.queueForPrefetch(child, priority: priority.rawValue)
                    }
                }
            }
        }
        
        // Handle any errors
        if !errors.isEmpty {
            throw BatchLoadError.partialFailure(errors)
        }
        
        return elements
    }
    
    // MARK: - Background Loading
    
    /// Start background loading task
    private func startBackgroundLoading() {
        backgroundTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled && !loadingQueue.isEmpty {
                // Process next batch
                let (range, priority) = loadingQueue.removeFirst()
                
                // Skip if already loading
                guard !isRangeLoading(range) else { continue }
                
                // Load batch
                do {
                    _ = try await loadBatch(
                        range: range,
                        priority: priority
                    ) { index in
                        // Provider stub - replace with actual implementation
                        throw BatchLoadError.notImplemented
                    }
                } catch {
                    // Handle errors
                    if let batchError = error as? BatchLoadError {
                        handleBatchError(batchError, range: range, priority: priority)
                    }
                }
                
                // Pause between batches
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
            backgroundTask = nil
        }
    }
    
    /// Check if range is currently loading
    private func isRangeLoading(_ range: Range<Int>) -> Bool {
        return activeBatches.contains { batch in
            range.overlaps(batch.startIndex..<batch.endIndex)
        }
    }
    
    /// Sort loading queue by priority
    private func sortLoadingQueue() {
        loadingQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - Error Handling
    
    private func handleBatchError(
        _ error: BatchLoadError,
        range: Range<Int>,
        priority: Config.Priority
    ) {
        switch error {
        case .partialFailure(let errors):
            // Retry failed indices
            let failedIndices = errors.map { $0.index }
            let retryRanges = splitRange(range, excluding: failedIndices)
            
            for retryRange in retryRanges {
                queueBatchLoad(range: retryRange, priority: priority)
            }
            
        case .notImplemented:
            // Log error
            print("Batch loading not implemented")
            
        case .timeout:
            // Retry with smaller batch size
            let midPoint = range.lowerBound + (range.count / 2)
            let firstHalf = range.lowerBound..<midPoint
            let secondHalf = midPoint..<range.upperBound
            
            queueBatchLoad(range: firstHalf, priority: priority)
            queueBatchLoad(range: secondHalf, priority: priority)
        }
    }
    
    /// Split range excluding specific indices
    private func splitRange(_ range: Range<Int>, excluding indices: [Int]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var current = range.lowerBound
        
        let sortedIndices = indices.sorted()
        for index in sortedIndices {
            if index > current {
                ranges.append(current..<index)
            }
            current = index + 1
        }
        
        if current < range.upperBound {
            ranges.append(current..<range.upperBound)
        }
        
        return ranges
    }
}

// MARK: - Supporting Types

/// Batch loading errors
enum BatchLoadError: Error {
    case partialFailure([(index: Int, error: Error)])
    case notImplemented
    case timeout
}