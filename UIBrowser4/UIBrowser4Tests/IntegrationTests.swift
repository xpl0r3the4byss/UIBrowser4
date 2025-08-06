import XCTest
@testable import UIBrowser4

/// Tests for integration between components
class IntegrationTests: XCTestCase {
    // MARK: - Element Browsing Flow Tests
    
    func testElementBrowsingFlow() async throws {
        // Setup components
        let targetManager = TargetApplicationManager.shared
        let dataModel = ElementDataModel.sharedInstance
        let cache = ElementCache.shared
        
        // Select target
        try await targetManager.selectSystemWideTarget()
        
        // Verify data model update
        XCTAssertFalse(dataModel.isEmpty)
        XCTAssertNotNil(await dataModel.currentElementNode)
        
        // Navigate hierarchy
        if let node = await dataModel.currentElementNode,
           let children = await dataModel.childNodes(of: node),
           let firstChild = children.first {
            
            // Update selection
            let path = await dataModel.indexPath(ofNode: firstChild)
            let level = path.length - 1
            let index = path.index(atPosition: level)
            
            try await dataModel.updateDataModelForCurrentElementAt(
                level: level,
                index: index
            )
            
            // Verify cache update
            let element = dataModel.element(ofNode: firstChild)
            XCTAssertNotNil(cache.getCachedAttributes(for: element))
        }
    }
    
    // MARK: - Script Generation Flow Tests
    
    func testScriptGenerationFlow() async throws {
        // Setup components
        let targetManager = TargetApplicationManager.shared
        let templateManager = AppleScriptTemplateManager.shared
        let executionManager = ScriptExecutionManager.shared
        
        // Select target
        try await targetManager.selectSystemWideTarget()
        
        // Generate script
        let element = try await createTestElement()
        let script = try await templateManager.generateScript(
            for: element,
            type: .systemEvents,
            style: .init()
        )
        
        // Execute script
        let result = try await executionManager.executeScript(script)
        XCTAssertNil(result.error)
    }
    
    // MARK: - Error Handling Flow Tests
    
    func testErrorHandlingFlow() async throws {
        // Setup components
        let errorSystem = ErrorHandlingSystem.shared
        let cache = ElementCache.shared
        
        // Setup observers
        var errorCount = 0
        var cancellables = Set<AnyCancellable>()
        
        errorSystem.errorOccurredPublisher
            .sink { _ in
                errorCount += 1
            }
            .store(in: &cancellables)
        
        // Trigger error condition
        let element = try await createTestElement()
        cache.invalidate(element)
        
        let context = ErrorHandlingSystem.ErrorContext(
            file: #file,
            function: #function,
            line: #line,
            timestamp: Date(),
            operationName: "Test"
        )
        
        try await errorSystem.handleError(
            AccessibilityError.elementDestroyed,
            severity: .warning,
            context: context
        )
        
        XCTAssertEqual(errorCount, 1)
    }
    
    // MARK: - View Update Flow Tests
    
    func testViewUpdateFlow() async throws {
        // Setup components
        let browser = BrowserTabItemViewController()
        let outline = OutlineTabItemViewController()
        let list = ListTabItemViewController()
        
        // Load views
        browser.loadView()
        outline.loadView()
        list.loadView()
        
        // Select target
        let targetManager = TargetApplicationManager.shared
        try await targetManager.selectSystemWideTarget()
        
        // Update views
        await browser.updateView()
        await outline.updateView()
        await list.updateView()
        
        // Verify synchronization
        let browserPath = browser.elementPathControlManager.pathControl?.pathItems
        let outlinePath = outline.elementPathControlManager.pathControl?.pathItems
        let listPath = list.elementPathControlManager.pathControl?.pathItems
        
        XCTAssertEqual(browserPath?.count, outlinePath?.count)
        XCTAssertEqual(outlinePath?.count, listPath?.count)
    }
    
    // MARK: - Recording Flow Tests
    
    func testRecordingFlow() async throws {
        // Setup components
        let executionManager = ScriptExecutionManager.shared
        let templateManager = AppleScriptTemplateManager.shared
        
        // Start recording
        executionManager.startRecording(name: "Test Recording")
        
        // Record actions
        let element = try await createTestElement()
        executionManager.recordStep(element: element, action: "click")
        
        // Generate script
        let style = AppleScriptTemplateManager.GenerationStyle()
        let script = try await templateManager.generateScript(
            for: element,
            type: .systemEvents,
            style: style
        )
        
        // Stop recording
        let recording = executionManager.stopRecording()
        XCTAssertNotNil(recording)
        
        // Execute recorded script
        let result = try await executionManager.executeScript(script)
        XCTAssertNil(result.error)
    }
    
    // MARK: - Performance Flow Tests
    
    func testPerformanceFlow() async throws {
        // Setup components
        let targetManager = TargetApplicationManager.shared
        let cache = ElementCache.shared
        let loader = ElementBatchLoader.shared
        
        measure {
            Task {
                // Select target
                try? await targetManager.selectSystemWideTarget()
                
                // Load initial batch
                let provider: (Int) async throws -> AccessibleElement = { index in
                    return try await self.createTestElement()
                }
                
                let batch = try? await loader.loadInitialBatch(
                    at: 0,
                    provider: provider
                )
                
                // Cache elements
                if let elements = batch {
                    for element in elements {
                        if let attributes = try? await element.allAttributes() {
                            cache.cacheAttributes(attributes, for: element)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Test Helpers
    
    private func createTestElement() async throws -> AccessibleElement {
        let app = NSRunningApplication.current
        return try await AccessibleElement.application(for: app!)
    }
}