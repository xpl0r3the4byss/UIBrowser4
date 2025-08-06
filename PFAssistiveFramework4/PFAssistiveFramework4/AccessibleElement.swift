import Foundation
import ApplicationServices

/// Errors that can occur when working with AccessibleElement
public enum AccessibleElementError: LocalizedError {
    case invalidProcessIdentifier
    case elementCreationFailed
    case attributeNotFound(String)
    case invalidAttributeValue(String)
    case notAuthorized
    case apiError(AXError)
    
    public var errorDescription: String? {
        switch self {
        case .invalidProcessIdentifier:
            return "Invalid process identifier"
        case .elementCreationFailed:
            return "Failed to create accessibility element"
        case .attributeNotFound(let attribute):
            return "Attribute not found: \(attribute)"
        case .invalidAttributeValue(let attribute):
            return "Invalid value for attribute: \(attribute)"
        case .notAuthorized:
            return "Application not authorized for accessibility access"
        case .apiError(let error):
            return "Accessibility API error: \(error)"
        }
    }
}

/// Protocol for observing element destruction
public protocol AccessibleElementDelegate: AnyObject {
    func elementWasDestroyed(_ element: AccessibleElement)
}

/// A class that wraps AXUIElement to provide a Swift-friendly interface to accessibility elements
public class AccessibleElement: NSObject {
    
    // MARK: - Properties
    
    /// The underlying AXUIElement
    private let axElement: AXUIElement
    
    /// The process ID of the application this element belongs to
    private let processID: pid_t
    
    /// Delegate to receive destruction notifications
    public weak var delegate: AccessibleElementDelegate?
    
    /// Whether this element observes destruction notifications
    private let observesDestruction: Bool
    
    /// Whether the element is still valid (not destroyed)
    public private(set) var isValid: Bool = true
    
    /// Whether the element has been destroyed
    public private(set) var isDestroyed: Bool = false
    
    /// Cached attributes for after destruction
    private var cachedAttributes: [String: Any] = [:]
    
    // MARK: - Initialization
    
    /// Creates an AccessibleElement wrapping the given AXUIElement
    /// - Parameters:
    ///   - axElement: The AXUIElement to wrap
    ///   - observesDestruction: Whether to observe destruction notifications
    public init?(axElement: AXUIElement, observesDestruction: Bool = true) throws {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(axElement, &pid)
        
        guard result == .success else {
            throw AccessibleElementError.apiError(result)
        }
        
        guard pid > 0 else {
            throw AccessibleElementError.invalidProcessIdentifier
        }
        
        self.axElement = axElement
        self.processID = pid
        self.observesDestruction = observesDestruction
        
        super.init()
        
        if observesDestruction {
            setupDestructionObserver()
            cacheAttributes()
        }
    }
    
    // MARK: - Factory Methods
    
    /// Creates an AccessibleElement representing the system-wide accessibility element
    public static func makeSystemWideElement() -> AccessibleElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        return try? AccessibleElement(axElement: systemWideElement)
    }
    
    /// Creates an AccessibleElement for the specified application
    /// - Parameter processIdentifier: The process ID of the application
    public static func makeApplicationElement(processIdentifier: pid_t) -> AccessibleElement? {
        guard processIdentifier > 0 else { return nil }
        let appElement = AXUIElementCreateApplication(processIdentifier)
        return try? AccessibleElement(axElement: appElement)
    }
    
    // MARK: - Attribute Access
    
    /// Gets the value of an accessibility attribute
    /// - Parameter attribute: The attribute to get
    /// - Returns: The attribute value
    public func getAttribute(_ attribute: String) async throws -> Any? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(axElement, attribute as CFString, &value)
        
        guard result != .attributeUnsupported else {
            return nil
        }
        
        guard result == .success else {
            throw AccessibleElementError.apiError(result)
        }
        
        return value
    }
    
    /// Sets the value of an accessibility attribute
    /// - Parameters:
    ///   - attribute: The attribute to set
    ///   - value: The new value
    public func setAttribute(_ attribute: String, value: Any) async throws {
        let result = AXUIElementSetAttributeValue(axElement, attribute as CFString, value as CFTypeRef)
        
        guard result == .success else {
            throw AccessibleElementError.apiError(result)
        }
    }
    
    // MARK: - Common Attributes
    
    /// The role of this element (e.g., "button", "window", etc.)
    public var AXRole: String? {
        get async throws {
            try await getAttribute(kAXRoleAttribute as String) as? String
        }
    }
    
    /// The parent of this element in the accessibility hierarchy
    public var AXParent: AccessibleElement? {
        get async throws {
            if let parentElement = try await getAttribute(kAXParentAttribute as String) as? AXUIElement {
                return try? AccessibleElement(axElement: parentElement)
            }
            return nil
        }
    }
    
    /// The children of this element in the accessibility hierarchy
    public var AXChildren: [AccessibleElement]? {
        get async throws {
            guard let children = try await getAttribute(kAXChildrenAttribute as String) as? [AXUIElement] else {
                return nil
            }
            
            return children.compactMap { element in
                try? AccessibleElement(axElement: element)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDestructionObserver() {
        // TODO: Implement destruction observation using AXObserver
    }
    
    private func cacheAttributes() {
        Task {
            // Cache common attributes that might be needed after destruction
            if let role = try? await AXRole {
                cachedAttributes[kAXRoleAttribute as String] = role
            }
            
            if let roleDesc = try? await getAttribute(kAXRoleDescriptionAttribute as String) {
                cachedAttributes[kAXRoleDescriptionAttribute as String] = roleDesc
            }
            
            if let title = try? await getAttribute(kAXTitleAttribute as String) {
                cachedAttributes[kAXTitleAttribute as String] = title
            }
            
            if let help = try? await getAttribute(kAXHelpAttribute as String) {
                cachedAttributes[kAXHelpAttribute as String] = help
            }
        }
    }
    
    // MARK: - Equality
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? AccessibleElement else { return false }
        return CFEqual(self.axElement, other.axElement)
    }
    
    public override var hash: Int {
        return CFHash(self.axElement)
    }
}