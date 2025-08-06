import XCTest
@testable import UIBrowser4

/// Tests for UI components and view controllers
class UIComponentTests: XCTestCase {
    // MARK: - View Controller Tests
    
    func testBrowserTabItemViewController() throws {
        let vc = BrowserTabItemViewController()
        
        // Load view
        vc.loadView()
        vc.viewDidLoad()
        
        // Verify setup
        XCTAssertNotNil(vc.elementBrowser)
        XCTAssertNotNil(vc.browserPathControl)
        XCTAssertNotNil(BrowserTabItemViewController.sharedInstance)
        
        // Test browser configuration
        XCTAssertEqual(vc.elementBrowser.controlSize, .small)
        XCTAssertFalse(vc.elementBrowser.takesTitleFromPreviousColumn)
    }
    
    func testOutlineTabItemViewController() throws {
        let vc = OutlineTabItemViewController()
        
        // Load view
        vc.loadView()
        vc.viewDidLoad()
        
        // Verify setup
        XCTAssertNotNil(vc.elementOutline)
        XCTAssertNotNil(vc.outlinePathControl)
        XCTAssertNotNil(OutlineTabItemViewController.sharedInstance)
        
        // Test outline configuration
        XCTAssertNotNil(vc.elementOutline.delegate)
        XCTAssertNotNil(vc.elementOutline.dataSource)
    }
    
    func testListTabItemViewController() throws {
        let vc = ListTabItemViewController()
        
        // Load view
        vc.loadView()
        vc.viewDidLoad()
        
        // Verify setup
        XCTAssertNotNil(vc.elementList)
        XCTAssertNotNil(vc.listPathControl)
        XCTAssertNotNil(ListTabItemViewController.sharedInstance)
        
        // Test list configuration
        XCTAssertNotNil(vc.elementList.delegate)
        XCTAssertNotNil(vc.elementList.dataSource)
    }
    
    func testActionInspectorViewController() throws {
        let vc = ActionInspectorViewController()
        
        // Load view
        vc.loadView()
        vc.viewDidLoad()
        
        // Verify setup
        XCTAssertNotNil(vc.tableView)
        XCTAssertNotNil(vc.executeButton)
        XCTAssertNotNil(ActionInspectorViewController.sharedInstance)
        
        // Test initial state
        XCTAssertFalse(vc.executeButton.isEnabled)
        XCTAssertTrue(vc.statusLabel.stringValue.isEmpty)
    }
    
    func testScriptGeneratorViewController() throws {
        let vc = ScriptGeneratorViewController()
        
        // Load view
        vc.loadView()
        vc.viewDidLoad()
        
        // Verify setup
        XCTAssertNotNil(vc.scriptTextView)
        XCTAssertNotNil(vc.stylePopUpButton)
        XCTAssertNotNil(ScriptGeneratorViewController.sharedInstance)
        
        // Test initial state
        XCTAssertFalse(vc.copyButton.isEnabled)
        XCTAssertFalse(vc.runButton.isEnabled)
    }
    
    // MARK: - Path Control Tests
    
    func testElementPathControlManager() async throws {
        let manager = ElementPathControlManager()
        let pathControl = NSPathControl()
        
        // Test target selection
        manager.updateTargetSelection(for: pathControl)
        XCTAssertFalse(pathControl.pathItems.isEmpty)
        
        // Test clear
        manager.clearPathControl(pathControl)
        XCTAssertTrue(pathControl.pathItems.isEmpty)
        
        // Test path display
        let element = try await createTestElement()
        manager.displayPathControl(pathControl)
        XCTAssertFalse(pathControl.pathItems.isEmpty)
    }
    
    // MARK: - Error View Tests
    
    func testErrorHistoryViewController() throws {
        let vc = ErrorHistoryViewController()
        
        // Load view
        vc.loadView()
        vc.viewDidLoad()
        
        // Verify setup
        XCTAssertNotNil(vc.tableView)
        XCTAssertNotNil(vc.severityPopup)
        XCTAssertNotNil(ErrorHistoryViewController.sharedInstance)
        
        // Test initial state
        XCTAssertFalse(vc.clearButton.isEnabled)
        XCTAssertEqual(vc.severityPopup.selectedItem?.title, "All Severities")
    }
    
    // MARK: - Virtualization Tests
    
    func testVirtualizedTableView() throws {
        let tableView = VirtualizedTableView()
        
        // Test initial state
        XCTAssertEqual(tableView.visibleRange, 0..<0)
        XCTAssertEqual(tableView.totalElements, 0)
        
        // Test range updates
        tableView.updateVisibleRange(0..<10)
        XCTAssertEqual(tableView.visibleRange, 0..<10)
    }
    
    func testVirtualizedOutlineView() throws {
        let outlineView = VirtualizedOutlineView()
        
        // Test initial state
        XCTAssertEqual(outlineView.visibleRange, 0..<0)
        XCTAssertEqual(outlineView.totalElements, 0)
        
        // Test range updates
        outlineView.updateVisibleRange(0..<10)
        XCTAssertEqual(outlineView.visibleRange, 0..<10)
    }
    
    // MARK: - View Integration Tests
    
    func testViewSynchronization() async throws {
        let browserVC = BrowserTabItemViewController()
        let outlineVC = OutlineTabItemViewController()
        let listVC = ListTabItemViewController()
        
        // Load views
        browserVC.loadView()
        outlineVC.loadView()
        listVC.loadView()
        
        // Create test element
        let element = try await createTestElement()
        
        // Update each view
        await browserVC.updateView()
        await outlineVC.updateView()
        await listVC.updateView()
        
        // Verify synchronization
        XCTAssertEqual(
            browserVC.elementPathControlManager.pathControl?.pathItems.count,
            outlineVC.elementPathControlManager.pathControl?.pathItems.count
        )
        XCTAssertEqual(
            outlineVC.elementPathControlManager.pathControl?.pathItems.count,
            listVC.elementPathControlManager.pathControl?.pathItems.count
        )
    }
    
    func testViewStateRestoration() throws {
        let browserVC = BrowserTabItemViewController()
        
        // Save state
        let state = try XCTUnwrap(browserVC.encodeRestorableState(with: NSCoder()))
        
        // Create new controller
        let newVC = BrowserTabItemViewController()
        
        // Restore state
        newVC.restoreState(with: state)
        
        // Verify restoration
        XCTAssertEqual(
            browserVC.elementBrowser.selectedRow(inColumn: 0),
            newVC.elementBrowser.selectedRow(inColumn: 0)
        )
    }
    
    // MARK: - Performance Tests
    
    func testViewUpdatePerformance() async throws {
        let browserVC = BrowserTabItemViewController()
        browserVC.loadView()
        
        measure {
            Task {
                await browserVC.updateView()
            }
        }
    }
    
    func testPathControlUpdatePerformance() throws {
        let manager = ElementPathControlManager()
        let pathControl = NSPathControl()
        
        measure {
            manager.updateTargetSelection(for: pathControl)
        }
    }
    
    // MARK: - Test Helpers
    
    private func createTestElement() async throws -> AccessibleElement {
        let app = NSRunningApplication.current
        return try await AccessibleElement.application(for: app!)
    }
}