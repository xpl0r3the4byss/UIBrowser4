import Foundation

/// High-performance caching system for accessibility elements
@MainActor
final class ElementCache {
    // MARK: - Types
    
    /// Cache entry containing element data and metadata
    private struct CacheEntry {
        let element: AccessibleElement
        let attributes: [String: Any]
        let timestamp: Date
        var accessCount: Int = 0
        var isValid: Bool = true
        
        /// Memory size estimation
        var estimatedSize: Int {
            var size = MemoryLayout<AccessibleElement>.size
            size += attributes.reduce(0) { count, entry in
                count + entry.key.count + (entry.value as? NSObject)?.memory ?? 0
            }
            return size
        }
    }
    
    /// Cache configuration
    struct Config {
        /// Maximum number of cached elements
        var maxElements: Int = 1000
        
        /// Maximum cache size in bytes
        var maxSize: Int = 50 * 1024 * 1024 // 50MB
        
        /// Time-to-live for cached entries
        var ttl: TimeInterval = 30.0
        
        /// Prefetch batch size
        var prefetchBatchSize: Int = 20
        
        /// Minimum access count for retention
        var minAccessCount: Int = 2
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ElementCache()
    
    /// Cache configuration
    private var config: Config
    
    /// Main element cache
    private var cache: [String: CacheEntry] = [:]
    
    /// Prefetch queue for background loading
    private var prefetchQueue: [(element: AccessibleElement, priority: Int)] = []
    
    /// Background task for cache maintenance
    private var maintenanceTask: Task<Void, Never>?
    
    /// Cache statistics
    private(set) var stats = CacheStats()
    
    // MARK: - Initialization
    
    private init(config: Config = Config()) {
        self.config = config
        startMaintenanceTask()
    }
    
    deinit {
        maintenanceTask?.cancel()
    }
    
    // MARK: - Cache Operations
    
    /// Get cached element attributes
    func getCachedAttributes(for element: AccessibleElement) -> [String: Any]? {
        let key = cacheKey(for: element)
        if var entry = cache[key] {
            // Update access count
            entry.accessCount += 1
            cache[key] = entry
            stats.hits += 1
            return entry.attributes
        }
        stats.misses += 1
        return nil
    }
    
    /// Cache element attributes
    func cacheAttributes(_ attributes: [String: Any], for element: AccessibleElement) {
        let key = cacheKey(for: element)
        let entry = CacheEntry(
            element: element,
            attributes: attributes,
            timestamp: Date()
        )
        
        // Check size constraints
        let newSize = (stats.currentSize + entry.estimatedSize)
        if newSize > config.maxSize {
            trimCache()
        }
        
        cache[key] = entry
        stats.currentSize = newSize
        stats.totalElements = cache.count
    }
    
    /// Invalidate cached element
    func invalidate(_ element: AccessibleElement) {
        let key = cacheKey(for: element)
        if var entry = cache[key] {
            entry.isValid = false
            cache[key] = entry
        }
    }
    
    /// Clear entire cache
    func clearCache() {
        cache.removeAll()
        stats.reset()
    }
    
    // MARK: - Prefetching
    
    /// Queue element for prefetching
    func queueForPrefetch(_ element: AccessibleElement, priority: Int = 0) {
        prefetchQueue.append((element, priority))
        sortPrefetchQueue()
        
        // Start prefetch if needed
        if prefetchQueue.count >= config.prefetchBatchSize {
            processPrefetchQueue()
        }
    }
    
    /// Process prefetch queue
    private func processPrefetchQueue() {
        guard !prefetchQueue.isEmpty else { return }
        
        Task {
            // Take batch from queue
            let batch = Array(prefetchQueue.prefix(config.prefetchBatchSize))
            prefetchQueue.removeFirst(min(config.prefetchBatchSize, prefetchQueue.count))
            
            // Fetch attributes for batch
            for (element, _) in batch {
                guard !Task.isCancelled else { return }
                
                if let attributes = try? await element.allAttributes() {
                    cacheAttributes(attributes, for: element)
                }
            }
        }
    }
    
    /// Sort prefetch queue by priority
    private func sortPrefetchQueue() {
        prefetchQueue.sort { $0.priority > $1.priority }
    }
    
    // MARK: - Cache Maintenance
    
    /// Start background maintenance task
    private func startMaintenanceTask() {
        maintenanceTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                trimCache()
                removeExpiredEntries()
            }
        }
    }
    
    /// Trim cache to stay within limits
    private func trimCache() {
        while cache.count > config.maxElements || stats.currentSize > config.maxSize {
            // Remove least accessed entries
            let sorted = cache.sorted { $0.value.accessCount < $1.value.accessCount }
            if let first = sorted.first {
                cache.removeValue(forKey: first.key)
                stats.currentSize -= first.value.estimatedSize
                stats.totalElements = cache.count
            } else {
                break
            }
        }
    }
    
    /// Remove expired entries
    private func removeExpiredEntries() {
        let now = Date()
        cache = cache.filter { key, entry in
            let age = now.timeIntervalSince(entry.timestamp)
            let keep = age < config.ttl && 
                      (entry.isValid || entry.accessCount >= config.minAccessCount)
            
            if !keep {
                stats.currentSize -= entry.estimatedSize
            }
            return keep
        }
        stats.totalElements = cache.count
    }
    
    // MARK: - Helpers
    
    /// Generate cache key for element
    private func cacheKey(for element: AccessibleElement) -> String {
        // Combine process ID and element address for unique key
        return "\(element.pid())_\(element.description)"
    }
}

// MARK: - Supporting Types

/// Cache statistics
struct CacheStats {
    var hits: Int = 0
    var misses: Int = 0
    var currentSize: Int = 0
    var totalElements: Int = 0
    
    mutating func reset() {
        hits = 0
        misses = 0
        currentSize = 0
        totalElements = 0
    }
}

/// Memory size estimation
private extension NSObject {
    var memory: Int {
        return malloc_size(Unmanaged.passUnretained(self).toOpaque())
    }
}