import XCTest
@testable import UIBrowser4

/// Tests for AppleScript generation functionality
class AppleScriptGenerationTests: XCTestCase {
    // MARK: - Properties
    
    private var templateManager: AppleScriptTemplateManager!
    private var testElement: AccessibleElement!
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        templateManager = AppleScriptTemplateManager.shared
        testElement = try await createTestElement()
    }
    
    override func tearDownWithError() throws {
        templateManager = nil
        testElement = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Template Tests
    
    func testSystemEventsTemplates() async throws {
        // Generate script
        let script = try await templateManager.generateScript(
            for: testElement,
            type: .systemEvents,
            style: .init()
        )
        
        // Verify script structure
        XCTAssertTrue(script.contains("tell application \"System Events\""))
        XCTAssertTrue(script.contains("end tell"))
        XCTAssertTrue(script.contains("property timeoutSeconds"))
    }
    
    func testAXElementTemplates() async throws {
        // Generate script
        let script = try await templateManager.generateScript(
            for: testElement,
            type: .axElement,
            style: .init()
        )
        
        // Verify script structure
        XCTAssertTrue(script.contains("use framework \"AppKit\""))
        XCTAssertTrue(script.contains("findElement(pid, searchPath)"))
        XCTAssertTrue(script.contains("property timeoutSeconds"))
    }
    
    func testHybridTemplates() async throws {
        // Generate script
        let script = try await templateManager.generateScript(
            for: testElement,
            type: .hybrid,
            style: .init()
        )
        
        // Verify script structure
        XCTAssertTrue(script.contains("use framework \"AppKit\""))
        XCTAssertTrue(script.contains("tell application \"System Events\""))
        XCTAssertTrue(script.contains("property timeoutSeconds"))
    }
    
    // MARK: - Generation Style Tests
    
    func testCommentGeneration() async throws {
        // Generate with comments
        let withComments = try await templateManager.generateScript(
            for: testElement,
            type: .systemEvents,
            style: .init(includeComments: true)
        )
        
        // Generate without comments
        let withoutComments = try await templateManager.generateScript(
            for: testElement,
            type: .systemEvents,
            style: .init(includeComments: false)
        )
        
        // Verify comment inclusion
        XCTAssertTrue(withComments.contains("--"))
        XCTAssertFalse(withoutComments.contains("--"))
    }
    
    func testNumericIndices() async throws {
        // Generate with numeric indices
        let withIndices = try await templateManager.generateScript(
            for: testElement,
            type: .systemEvents,
            style: .init(useNumericIndices: true)
        )
        
        // Generate without numeric indices
        let withoutIndices = try await templateManager.generateScript(
            for: testElement,
            type: .systemEvents,
            style: .init(useNumericIndices: false)
        )
        
        // Verify index inclusion
        XCTAssertTrue(withIndices.contains(" 1 of "))
        XCTAssertFalse(withoutIndices.contains(" 1 of "))
    }
    
    func testErrorHandling() async throws {
        // Generate with error handling
        let withHandling = try await templateManager.generateScript(
            for: testElement,
            type: .systemEvents,
            style: .init(addErrorHandling: true)
        )
        
        // Generate without error handling
        let withoutHandling = try await templateManager.generateScript(
            for: testElement,
            type: .systemEvents,
            style: .init(addErrorHandling: false)
        )
        
        // Verify error handling inclusion
        XCTAssertTrue(withHandling.contains("try"))
        XCTAssertTrue(withHandling.contains("on error"))
        XCTAssertFalse(withoutHandling.contains("try"))
    }
    
    // MARK: - Element Type Tests
    
    func testButtonScriptGeneration() async throws {
        // Create button element
        let button = try await createTestButton()
        
        // Generate script
        let script = try await templateManager.generateScript(
            for: button,
            type: .systemEvents,
            style: .init()
        )
        
        // Verify button-specific content
        XCTAssertTrue(script.contains("button"))
        XCTAssertTrue(script.contains("click"))
    }
    
    func testTextFieldScriptGeneration() async throws {
        // Create text field element
        let textField = try await createTestTextField()
        
        // Generate script
        let script = try await templateManager.generateScript(
            for: textField,
            type: .systemEvents,
            style: .init()
        )
        
        // Verify text field-specific content
        XCTAssertTrue(script.contains("text field"))
        XCTAssertTrue(script.contains("set value of"))
    }
    
    func testMenuItemScriptGeneration() async throws {
        // Create menu item element
        let menuItem = try await createTestMenuItem()
        
        // Generate script
        let script = try await templateManager.generateScript(
            for: menuItem,
            type: .systemEvents,
            style: .init()
        )
        
        // Verify menu item-specific content
        XCTAssertTrue(script.contains("menu item"))
        XCTAssertTrue(script.contains("click"))
    }
    
    // MARK: - Custom Template Tests
    
    func testCustomTemplateManagement() throws {
        // Create custom template
        let template = """
            -- Custom template
            tell application "System Events"
                {content}
            end tell
            """
        
        // Save template
        try templateManager.saveCustomTemplate(template, named: "Custom")
        
        // Verify template exists
        XCTAssertNotNil(templateManager.customTemplate(named: "Custom"))
        XCTAssertEqual(templateManager.customTemplate(named: "Custom"), template)
    }
    
    // MARK: - Performance Tests
    
    func testScriptGenerationPerformance() async throws {
        let style = AppleScriptTemplateManager.GenerationStyle()
        
        measure {
            Task {
                _ = try? await templateManager.generateScript(
                    for: testElement,
                    type: .systemEvents,
                    style: style
                )
            }
        }
    }
    
    // MARK: - Test Helpers
    
    private func createTestElement() async throws -> AccessibleElement {
        let app = NSRunningApplication.current
        return try await AccessibleElement.application(for: app!)
    }
    
    private func createTestButton() async throws -> AccessibleElement {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        button.title = "Test Button"
        return try await AccessibleElement.create(for: button)
    }
    
    private func createTestTextField() async throws -> AccessibleElement {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        field.stringValue = "Test Field"
        return try await AccessibleElement.create(for: field)
    }
    
    private func createTestMenuItem() async throws -> AccessibleElement {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Test Item", action: nil, keyEquivalent: "")
        menu.addItem(item)
        return try await AccessibleElement.create(for: item)
    }
}