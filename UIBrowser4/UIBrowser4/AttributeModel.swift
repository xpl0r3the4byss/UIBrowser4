import Foundation
import Combine

/// Model representing an accessibility element's attributes
@MainActor
class AttributeModel {
    /// Attribute types that can be inspected
    enum AttributeType: String, CaseIterable {
        case role = "AXRole"
        case subrole = "AXSubrole"
        case roleDescription = "AXRoleDescription"
        case title = "AXTitle"
        case help = "AXHelp"
        case identifier = "AXIdentifier"
        case focused = "AXFocused"
        case enabled = "AXEnabled"
        case selected = "AXSelected"
        case value = "AXValue"
        case description = "AXDescription"
        case parent = "AXParent"
        case children = "AXChildren"
        case size = "AXSize"
        case position = "AXPosition"
        case window = "AXWindow"
        case topLevelUIElement = "AXTopLevelUIElement"
        case application = "AXApplication"
    }
    
    /// Shared instance
    static var shared = AttributeModel()
    
    /// Current attribute values for selected element
    private(set) var attributes: [AttributeType: Any] = [:]
    
    /// Publisher for attribute updates
    let attributesPublisher = PassthroughSubject<[AttributeType: Any], Never>()
    
    /// Search filter string
    private var searchFilter: String = ""
    
    /// Publisher for filtered attributes
    let filteredAttributesPublisher = PassthroughSubject<[AttributeType], Never>()
    
    /// Filter attributes by search string
    func filterAttributes(searchTerm: String) {
        searchFilter = searchTerm.lowercased()
        updateFilteredAttributes()
    }
    
    /// Update filtered attributes based on current search filter
    private func updateFilteredAttributes() {
        if searchFilter.isEmpty {
            filteredAttributesPublisher.send(Array(AttributeType.allCases))
            return
        }
        
        let filtered = AttributeType.allCases.filter { type in
            let name = type.rawValue.replacingOccurrences(of: "AX", with: "").lowercased()
            let value = formattedValue(for: type).lowercased()
            return name.contains(searchFilter) || value.contains(searchFilter)
        }
        
        filteredAttributesPublisher.send(filtered)
    }
    
    /// Update attributes for a given element
    func updateAttributes(for element: AccessibleElement) async throws {
        attributes.removeAll()
        
        // Core attributes
        attributes[.role] = element.AXRole
        attributes[.subrole] = element.AXSubrole
        attributes[.roleDescription] = element.AXRoleDescription
        attributes[.title] = element.AXTitle
        attributes[.help] = element.AXHelp
        attributes[.identifier] = element.AXIdentifier
        
        // State attributes
        attributes[.focused] = element.AXFocused
        attributes[.enabled] = element.AXEnabled
        attributes[.selected] = element.AXSelected
        attributes[.value] = element.AXValue
        attributes[.description] = element.AXDescription
        
        // Hierarchy attributes  
        attributes[.parent] = element.AXParent
        attributes[.children] = element.AXChildren
        
        // Geometry attributes
        attributes[.size] = element.AXSize
        attributes[.position] = element.AXPosition
        
        // Container attributes
        attributes[.window] = element.AXWindow
        attributes[.topLevelUIElement] = element.AXTopLevelUIElement
        attributes[.application] = element.AXApplication
        
        // Notify subscribers
        attributesPublisher.send(attributes)
        
        // Update filtered results
        updateFilteredAttributes()
    }
    
    /// Get formatted string value for an attribute
    func formattedValue(for type: AttributeType) -> String {
        guard let value = attributes[type] else { return "–" }
        
        switch type {
        case .role, .subrole, .roleDescription, .title, .help, .identifier, .description:
            return value as? String ?? "–"
            
        case .focused, .enabled, .selected:
            return (value as? Bool)?.description ?? "–"
            
        case .value:
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.description
            } else {
                return "–"
            }
            
        case .parent, .window, .topLevelUIElement, .application:
            if let element = value as? AccessibleElement {
                return element.AXRole ?? "–"
            }
            return "–"
            
        case .children:
            if let children = value as? [AccessibleElement] {
                return "\(children.count) elements"
            }
            return "–"
            
        case .size:
            if let size = value as? NSSize {
                return String(format: "%.1f x %.1f", size.width, size.height)
            }
            return "–"
            
        case .position:
            if let point = value as? NSPoint {
                return String(format: "(%.1f, %.1f)", point.x, point.y)
            }
            return "–"
        }
    }
}