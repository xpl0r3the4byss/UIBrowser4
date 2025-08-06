import XCTest
@testable import UIBrowser4

/// Tests for manager and service classes
class ManagerTests: XCTestCase {
    // MARK: - Target Application Manager Tests
    
    func testTargetApplicationManager() async throws {
        let manager = TargetApplicationManager.shared
        
        // Test system-wide target
        try await manager.selectSystemWideTarget()
        if case .systemWide = manager.currentTarget {
            // Expected state
        } else {
            XCTFail("Wrong target state")
        }
        
        // Test application target
        let app = NSRunningApplication.current
        try await manager.selectApplicationTarget(app!)
        if case .application(let target) = manager.currentTarget {
            XCTAssertEqual(target, app)
        } else {
            XCTFail("Wrong target state")
        }
        
        // Test clear target
        manager.clearTarget()
        if case .none = manager.currentTarget {
            // Expected state
        } else {
            XCTFail("Wrong target state")
        }
        
        // Test recent targets
        let recent = manager.getRecentTargets()
        XCTAssertFalse(recent.isEmpty)
        XCTAssertEqual(recent.first, app)
    }
    
    // MARK: - Process Monitor Tests
    
    func testProcessMonitor() async throws {
        let monitor = ProcessMonitor.shared
        
        // Setup expectation
        let expectation = XCTestExpectation(description: "Process change")
        
        // Add observer
        var cancellables = Set<AnyCancellable>()
        monitor.processChangePublisher
            .sink { change in
                if change.type == .launched {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start monitoring
        monitor.startMonitoring(ProcessInfo.processInfo.processIdentifier)
        
        // Launch test process
        let task = Process()
        task.launchPath = "/usr/bin/true"
        task.launch()
        
        // Wait for observation
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Stop monitoring
        monitor.stopMonitoring(ProcessInfo.processInfo.processIdentifier)
    }
    
    // MARK: - Element Cache Tests
    
    func testElementCache() async throws {
        let cache = ElementCache.shared
        
        // Create test element
        let element = try await createTestElement()
        let attributes = ["AXRole": "AXApplication"]
        
        // Test caching
        cache.cacheAttributes(attributes, for: element)
        let cached = cache.getCachedAttributes(for: element)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?["AXRole"] as? String, "AXApplication")
        
        // Test invalidation
        cache.invalidate(element)
        let invalid = cache.getCachedAttributes(for: element)
        XCTAssertNil(invalid)
        
        // Test clear
        cache.clearCache()
        let cleared = cache.getCachedAttributes(for: element)
        XCTAssertNil(cleared)
    }
    
    // MARK: - Element Batch Loader Tests
    
    func testElementBatchLoader() async throws {
        let loader = ElementBatchLoader.shared
        
        // Create test provider
        let provider: (Int) async throws -> AccessibleElement = { index in
            return try await self.createTestElement()
        }
        
        // Test initial batch
        let batch = try await loader.loadInitialBatch(at: 0, provider: provider)
        XCTAssertFalse(batch.isEmpty)
        
        // Test batch queuing
        loader.queueBatchLoad(range: 0..<10)
        loader.queueBatchLoad(range: 10..<20, priority: .visible)
    }
    
    // MARK: - Theme Manager Tests
    
    func testThemeManager() async throws {
        let manager = ThemeManager.shared
        
        // Test color updates
        var updates = 0
        var cancellables = Set<AnyCancellable>()
        
        manager.colorsPublisher
            .sink { _ in
                updates += 1
            }
            .store(in: &cancellables)
        
        // Test theme changes
        manager.config.followSystem = false
        manager.config.prefersDarkMode = true
        XCTAssertEqual(updates, 2)
        
        // Test accent color
        if let color = NSColor.AccentColor(rawValue: 0) {
            manager.setAccentColor(color)
        }
    }
    
    // MARK: - Error Handling System Tests
    
    func testErrorHandlingSystem() async throws {
        let system = ErrorHandlingSystem.shared
        
        // Create test error
        let error = NSError(domain: "Test", code: 1, userInfo: nil)
        let context = ErrorHandlingSystem.ErrorContext(
            file: #file,
            function: #function,
            line: #line,
            timestamp: Date(),
            operationName: "Test"
        )
        
        // Test error handling
        try await system.handleError(error, severity: .warning, context: context)
        
        // Test strategy registration
        system.registerStrategy(.retry(maxAttempts: 3), for: "Test")
        try await system.handleError(error, severity: .warning, context: context)
        
        // Test error history
        let history = system.getErrorHistory(severity: .warning)
        XCTAssertFalse(history.isEmpty)
    }
    
    // MARK: - Help Manager Tests
    
    func testHelpManager() throws {
        let manager = HelpManager.shared
        
        // Test topic access
        let topic = manager.topic(for: "test")
        XCTAssertNil(topic)
        
        // Test search
        let results = manager.searchTopics("test")
        XCTAssertTrue(results.isEmpty)
        
        // Test tooltips
        let tooltip = manager.tooltip(for: "browser.view")
        XCTAssertNotNil(tooltip)
    }
    
    // MARK: - Preferences Manager Tests
    
    func testPreferencesManager() throws {
        let manager = PreferencesManager.shared
        
        // Test value access
        let value: Bool = manager.value(for: .showPathControls) ?? false
        XCTAssertTrue(value)
        
        // Test value setting
        manager.setValue(false, for: .showPathControls)
        let updated: Bool = manager.value(for: .showPathControls) ?? true
        XCTAssertFalse(updated)
        
        // Test domain reset
        manager.resetDomain(.standard)
        let reset: Bool = manager.value(for: .showPathControls) ?? false
        XCTAssertTrue(reset)
        
        // Test export/import
        let data = try manager.exportPreferences()
        try manager.importPreferences(data)
    }
    
    // MARK: - Performance Tests
    
    func testCachePerformance() async throws {
        let cache = ElementCache.shared
        let element = try await createTestElement()
        let attributes = ["test": "value"]
        
        measure {
            cache.cacheAttributes(attributes, for: element)
            _ = cache.getCachedAttributes(for: element)
            cache.invalidate(element)
        }
    }
    
    func testBatchLoaderPerformance() async throws {
        let loader = ElementBatchLoader.shared
        
        measure {
            for i in 0..<100 {
                loader.queueBatchLoad(range: i..<(i+10))
            }
        }
    }
    
    // MARK: - Test Helpers
    
    private func createTestElement() async throws -> AccessibleElement {
        let app = NSRunningApplication.current
        return try await AccessibleElement.application(for: app!)
    }
}