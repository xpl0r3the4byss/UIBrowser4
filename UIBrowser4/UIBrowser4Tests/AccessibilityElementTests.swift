import XCTest
@testable import UIBrowser4

/// Tests for accessibility element functionality
class AccessibilityElementTests: XCTestCase {
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Enable accessibility for testing
        try enableAccessibilityForTesting()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Reset state
        ElementCache.shared.clearCache()
    }
    
    // MARK: - Element Creation Tests
    
    func testSystemWideElementCreation() async throws {
        // Create system-wide element
        let element = try await AccessibleElement.systemWide()
        
        // Verify properties
        XCTAssertNotNil(element)
        XCTAssertEqual(element.AXRole, "AXSystemWide")
        XCTAssertNotNil(element.element)
    }
    
    func testApplicationElementCreation() async throws {
        // Get running application
        guard let app = NSRunningApplication.current else {
            XCTFail("Could not get current application")
            return
        }
        
        // Create application element
        let element = try await AccessibleElement.application(for: app)
        
        // Verify properties
        XCTAssertNotNil(element)
        XCTAssertEqual(element.AXRole, "AXApplication")
        XCTAssertEqual(await element.pid(), app.processIdentifier)
    }
    
    func testWindowElementCreation() async throws {
        // Create test window
        let window = createTestWindow()
        
        // Create window element
        let element = try await AccessibleElement.window(for: window)
        
        // Verify properties
        XCTAssertNotNil(element)
        XCTAssertEqual(element.AXRole, "AXWindow")
        XCTAssertNotNil(element.AXParent)
    }
    
    // MARK: - Attribute Tests
    
    func testBasicAttributeAccess() async throws {
        // Create test element
        let button = createTestButton()
        let element = try await AccessibleElement.create(for: button)
        
        // Test attribute access
        XCTAssertEqual(element.AXRole, "AXButton")
        XCTAssertEqual(element.AXTitle, "Test Button")
        XCTAssertTrue(element.AXEnabled as? Bool ?? false)
    }
    
    func testAttributeModification() async throws {
        // Create test element
        let textField = createTestTextField()
        let element = try await AccessibleElement.create(for: textField)
        
        // Modify attribute
        try await element.setValue("New Value", forAttribute: "AXValue")
        
        // Verify change
        XCTAssertEqual(element.AXValue as? String, "New Value")
        XCTAssertEqual(textField.stringValue, "New Value")
    }
    
    func testAttributeObservation() async throws {
        // Create test element
        let button = createTestButton()
        let element = try await AccessibleElement.create(for: button)
        
        // Setup expectation
        let expectation = XCTestExpectation(description: "Attribute changed")
        
        // Start observation
        let task = Task {
            for await event in element.observeAttribute("AXEnabled") {
                if event.newValue as? Bool == false {
                    expectation.fulfill()
                    break
                }
            }
        }
        
        // Modify attribute
        button.isEnabled = false
        
        // Wait for observation
        await fulfillment(of: [expectation], timeout: 5.0)
        task.cancel()
    }
    
    // MARK: - Hierarchy Tests
    
    func testParentChildRelationships() async throws {
        // Create test hierarchy
        let window = createTestWindow()
        let parent = try await AccessibleElement.window(for: window)
        
        // Add child elements
        let button = createTestButton()
        window.contentView?.addSubview(button)
        
        // Get children
        let children = await parent.children
        
        // Verify relationships
        XCTAssertNotNil(children)
        XCTAssertGreaterThan(children?.count ?? 0, 0)
        
        if let child = children?.first {
            XCTAssertEqual(child.AXParent?.AXRole, parent.AXRole)
        }
    }
    
    func testElementPath() async throws {
        // Create test hierarchy
        let window = createTestWindow()
        let button = createTestButton()
        window.contentView?.addSubview(button)
        
        // Get element
        let element = try await AccessibleElement.create(for: button)
        
        // Get path
        let path = try await element.elementPath()
        
        // Verify path components
        XCTAssertTrue(path.contains("AXApplication"))
        XCTAssertTrue(path.contains("AXWindow"))
        XCTAssertTrue(path.contains("AXButton"))
    }
    
    // MARK: - Action Tests
    
    func testActionAvailability() async throws {
        // Create test element
        let button = createTestButton()
        let element = try await AccessibleElement.create(for: button)
        
        // Check action availability
        let canPress = await element.canPerformAction("AXPress")
        XCTAssertTrue(canPress)
        
        let cannotJump = await element.canPerformAction("AXJump")
        XCTAssertFalse(cannotJump)
    }
    
    func testActionExecution() async throws {
        // Create test element
        let button = createTestButton()
        let element = try await AccessibleElement.create(for: button)
        
        // Setup expectation
        let expectation = XCTestExpectation(description: "Button pressed")
        button.target = self
        button.action = #selector(buttonPressed)
        self.pressExpectation = expectation
        
        // Perform action
        try await element.performAction("AXPress")
        
        // Wait for action
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidElementAccess() async throws {
        // Create element that will be destroyed
        let button = createTestButton()
        let element = try await AccessibleElement.create(for: button)
        
        // Destroy element
        button.removeFromSuperview()
        
        // Attempt access
        do {
            _ = try await element.value(forAttribute: "AXRole")
            XCTFail("Should throw error for destroyed element")
        } catch {
            XCTAssertTrue(error is AccessibilityError)
        }
    }
    
    func testInvalidAttributeAccess() async throws {
        // Create test element
        let button = createTestButton()
        let element = try await AccessibleElement.create(for: button)
        
        // Attempt invalid attribute access
        do {
            _ = try await element.value(forAttribute: "InvalidAttribute")
            XCTFail("Should throw error for invalid attribute")
        } catch {
            XCTAssertTrue(error is AccessibilityError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testAttributeAccessPerformance() async throws {
        // Create test element
        let button = createTestButton()
        let element = try await AccessibleElement.create(for: button)
        
        // Measure performance
        measure {
            _ = element.AXRole
            _ = element.AXTitle
            _ = element.AXEnabled
        }
    }
    
    func testHierarchyTraversalPerformance() async throws {
        // Create deep hierarchy
        let window = createTestWindow()
        createDeepHierarchy(in: window.contentView!, depth: 5, breadth: 3)
        
        // Get root element
        let element = try await AccessibleElement.window(for: window)
        
        // Measure performance
        measure {
            Task {
                _ = await element.recursiveDescendants()
            }
        }
    }
    
    // MARK: - Test Helpers
    
    private var pressExpectation: XCTestExpectation?
    
    @objc private func buttonPressed() {
        pressExpectation?.fulfill()
    }
    
    private func createTestWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Test Window"
        return window
    }
    
    private func createTestButton() -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        button.title = "Test Button"
        button.bezelStyle = .rounded
        return button
    }
    
    private func createTestTextField() -> NSTextField {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        field.stringValue = "Test Field"
        return field
    }
    
    private func createDeepHierarchy(in view: NSView, depth: Int, breadth: Int) {
        guard depth > 0 else { return }
        
        for _ in 0..<breadth {
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            view.addSubview(container)
            createDeepHierarchy(in: container, depth: depth - 1, breadth: breadth)
        }
    }
    
    private func enableAccessibilityForTesting() throws {
        // Request accessibility access if needed
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            throw XCTestError(.failureWhileWaiting, userInfo: [
                XCTestErrorUserInfoKey.description: "Accessibility access not granted"
            ])
        }
    }
}

// MARK: - Test Extensions

extension AccessibleElement {
    /// Get all descendants recursively
    func recursiveDescendants() async -> [AccessibleElement] {
        var descendants: [AccessibleElement] = []
        
        if let children = await self.children {
            descendants.append(contentsOf: children)
            for child in children {
                let childDescendants = await child.recursiveDescendants()
                descendants.append(contentsOf: childDescendants)
            }
        }
        
        return descendants
    }
}