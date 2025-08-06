import XCTest
@testable import UIBrowser4

/// Tests for script execution and recording functionality
class ScriptExecutionTests: XCTestCase {
    // MARK: - Properties
    
    private var executionManager: ScriptExecutionManager!
    private var testElement: AccessibleElement!
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        executionManager = ScriptExecutionManager.shared
        testElement = try await createTestElement()
    }
    
    override func tearDownWithError() throws {
        executionManager = nil
        testElement = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Execution Tests
    
    func testBasicScriptExecution() async throws {
        // Create test script
        let script = """
            tell application "System Events"
                return "success"
            end tell
            """
        
        // Execute script
        let result = try await executionManager.executeScript(script)
        
        // Verify result
        XCTAssertNil(result.error)
        XCTAssertEqual(result.output, "success")
        XCTAssertGreaterThan(result.duration, 0)
    }
    
    func testScriptExecutionTimeout() async throws {
        // Create long-running script
        let script = """
            tell application "System Events"
                delay 10
            end tell
            """
        
        // Execute with short timeout
        let options = ScriptExecutionManager.ExecutionOptions(timeout: 1.0)
        
        do {
            _ = try await executionManager.executeScript(script, options: options)
            XCTFail("Should throw timeout error")
        } catch {
            XCTAssertTrue(error is ScriptError)
            if case ScriptError.timeout = error {
                // Expected error
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testScriptExecutionError() async throws {
        // Create invalid script
        let script = """
            tell application "Invalid App"
                do something invalid
            end tell
            """
        
        do {
            _ = try await executionManager.executeScript(script)
            XCTFail("Should throw execution error")
        } catch {
            XCTAssertTrue(error is ScriptError)
        }
    }
    
    func testExecutionHistory() async throws {
        // Clear history
        executionManager.clearExecutionHistory()
        
        // Execute scripts
        let script1 = "return 1"
        let script2 = "return 2"
        
        _ = try await executionManager.executeScript(script1)
        _ = try await executionManager.executeScript(script2)
        
        // Check history
        let history = executionManager.getExecutionHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].script, script2)
        XCTAssertEqual(history[1].script, script1)
    }
    
    // MARK: - Recording Tests
    
    func testScriptRecording() async throws {
        // Start recording
        executionManager.startRecording(name: "Test Recording")
        
        // Record steps
        executionManager.recordStep(
            element: testElement,
            action: "click"
        )
        
        executionManager.recordStep(
            element: testElement,
            action: "setValue",
            parameters: ["value": "test"]
        )
        
        // Stop recording
        let recording = executionManager.stopRecording()
        
        // Verify recording
        XCTAssertNotNil(recording)
        XCTAssertEqual(recording?.name, "Test Recording")
        XCTAssertEqual(recording?.steps.count, 2)
        XCTAssertEqual(recording?.steps[0].action, "click")
        XCTAssertEqual(recording?.steps[1].action, "setValue")
    }
    
    func testMultipleRecordings() async throws {
        // Start first recording
        executionManager.startRecording(name: "Recording 1")
        executionManager.recordStep(element: testElement, action: "click")
        let recording1 = executionManager.stopRecording()
        
        // Start second recording
        executionManager.startRecording(name: "Recording 2")
        executionManager.recordStep(element: testElement, action: "setValue")
        let recording2 = executionManager.stopRecording()
        
        // Verify recordings
        XCTAssertNotNil(recording1)
        XCTAssertNotNil(recording2)
        XCTAssertEqual(recording1?.name, "Recording 1")
        XCTAssertEqual(recording2?.name, "Recording 2")
        XCTAssertEqual(recording1?.steps.count, 1)
        XCTAssertEqual(recording2?.steps.count, 1)
    }
    
    func testRecordingPlayback() async throws {
        // Create recording
        executionManager.startRecording(name: "Test Recording")
        executionManager.recordStep(element: testElement, action: "click")
        let recording = executionManager.stopRecording()
        
        // Generate script
        guard let script = recording?.script else {
            XCTFail("No script generated")
            return
        }
        
        // Execute generated script
        let result = try await executionManager.executeScript(script)
        
        // Verify execution
        XCTAssertNil(result.error)
    }
    
    // MARK: - Observer Tests
    
    func testExecutionObservers() async throws {
        // Setup expectation
        let expectation = XCTestExpectation(description: "Execution observed")
        
        // Add observer
        let id = executionManager.addExecutionObserver { result in
            XCTAssertNil(result.error)
            expectation.fulfill()
        }
        
        // Execute script
        let script = "return true"
        _ = try await executionManager.executeScript(script)
        
        // Wait for observation
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Remove observer
        executionManager.removeExecutionObserver(id)
    }
    
    // MARK: - Performance Tests
    
    func testExecutionPerformance() async throws {
        let script = "return true"
        
        measure {
            Task {
                _ = try? await executionManager.executeScript(script)
            }
        }
    }
    
    // MARK: - Test Helpers
    
    private func createTestElement() async throws -> AccessibleElement {
        let app = NSRunningApplication.current
        return try await AccessibleElement.application(for: app!)
    }
}