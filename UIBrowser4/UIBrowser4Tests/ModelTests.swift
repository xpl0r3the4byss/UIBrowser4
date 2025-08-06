import XCTest
@testable import UIBrowser4

/// Tests for data models and utilities
class ModelTests: XCTestCase {
    // MARK: - Element Data Model Tests
    
    func testElementDataModel() async throws {
        let model = ElementDataModel.sharedInstance
        
        // Test initialization
        XCTAssertTrue(model.isEmpty)
        XCTAssertNil(model.currentElementIndexPath)
        
        // Test target update
        let element = try await createTestElement()
        model.updateForNewTarget(element)
        XCTAssertFalse(model.isEmpty)
        
        // Test path management
        let path = await model.currentElementIndexPath
        XCTAssertNotNil(path)
        XCTAssertEqual(path?.length, 1)
        
        // Test node access
        let node = await model.currentElementNode
        XCTAssertNotNil(node)
        
        // Test clear
        model.clear()
        XCTAssertTrue(model.isEmpty)
    }
    
    // MARK: - Attribute Model Tests
    
    func testAttributeModel() async throws {
        let model = AttributeModel.shared
        
        // Test attribute update
        let element = try await createTestElement()
        try await model.updateAttributes(for: element)
        
        // Test attribute access
        for type in AttributeModel.AttributeType.allCases {
            let value = model.formattedValue(for: type)
            XCTAssertNotNil(value)
        }
    }
    
    // MARK: - Element Node Tests
    
    func testElementNodeInfo() async throws {
        let model = ElementDataModel.sharedInstance
        let element = try await createTestElement()
        
        // Create node
        let node = model.createNode(for: element)
        
        // Test properties
        XCTAssertEqual(node.role, element.AXRole)
        XCTAssertEqual(node.title, element.AXTitle)
        XCTAssertFalse(node.isEmpty)
        
        // Test children
        let children = await model.childNodes(of: node)
        XCTAssertNotNil(children)
    }
    
    // MARK: - Element Path Tests
    
    func testElementPath() async throws {
        let element = try await createTestElement()
        
        // Get path
        let path = try await element.elementPath()
        
        // Test components
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains("AXApplication"))
        
        // Test parsing
        let components = path.components(separatedBy: "/")
        XCTAssertGreaterThan(components.count, 0)
    }
    
    // MARK: - Script Model Tests
    
    func testScriptRecording() {
        let manager = ScriptExecutionManager.shared
        
        // Create recording
        manager.startRecording(name: "Test")
        
        // Add steps
        let step = ScriptExecutionManager.ScriptRecording.RecordingStep(
            element: MockElement(),
            action: "click",
            parameters: [:],
            timestamp: Date()
        )
        
        // Stop recording
        let recording = manager.stopRecording()
        XCTAssertNotNil(recording)
        XCTAssertEqual(recording?.name, "Test")
    }
    
    // MARK: - Theme Model Tests
    
    func testThemeColors() {
        // Test light theme
        let light = ThemeManager.ThemeColors.light
        XCTAssertNotNil(light.textColor)
        XCTAssertNotNil(light.backgroundColor)
        XCTAssertNotNil(light.accentColor)
        
        // Test dark theme
        let dark = ThemeManager.ThemeColors.dark
        XCTAssertNotNil(dark.textColor)
        XCTAssertNotNil(dark.backgroundColor)
        XCTAssertNotNil(dark.accentColor)
    }
    
    // MARK: - Error Model Tests
    
    func testErrorRecords() {
        let system = ErrorHandlingSystem.shared
        
        // Create error
        let error = NSError(domain: "Test", code: 1, userInfo: nil)
        let context = ErrorHandlingSystem.ErrorContext(
            file: "test",
            function: "test",
            line: 1,
            timestamp: Date(),
            operationName: "Test"
        )
        
        // Create record
        let record = ErrorHandlingSystem.ErrorRecord(
            error: error,
            severity: .warning,
            context: context,
            timestamp: Date(),
            resolution: .handled
        )
        
        // Test properties
        XCTAssertNotNil(record.id)
        XCTAssertEqual(record.severity, .warning)
        XCTAssertEqual(record.resolution, .handled)
    }
    
    // MARK: - Utility Tests
    
    func testDynamicColors() {
        // Create dynamic color
        let color = NSColor.dynamicColor(
            light: .textColor,
            dark: .textColor
        )
        
        // Test appearance adaptation
        let lightAppearance = NSAppearance(named: .aqua)!
        let darkAppearance = NSAppearance(named: .darkAqua)!
        
        NSAppearance.current = lightAppearance
        let lightColor = color.usingColorSpace(.genericRGB)
        
        NSAppearance.current = darkAppearance
        let darkColor = color.usingColorSpace(.genericRGB)
        
        XCTAssertNotNil(lightColor)
        XCTAssertNotNil(darkColor)
    }
    
    // MARK: - Test Helpers
    
    private func createTestElement() async throws -> AccessibleElement {
        let app = NSRunningApplication.current
        return try await AccessibleElement.application(for: app!)
    }
}

/// Mock element for testing
private class MockElement: AccessibleElement {
    override var AXRole: String? { "MockElement" }
    override var AXTitle: String? { "Mock" }
    
    override init() {
        super.init()
    }
}