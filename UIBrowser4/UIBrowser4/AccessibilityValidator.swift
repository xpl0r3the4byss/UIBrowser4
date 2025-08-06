import Foundation
import Combine

/// Validator for accessibility guidelines and best practices
@MainActor
final class AccessibilityValidator {
    // MARK: - Types
    
    /// Validation rule type
    enum RuleType: String, CaseIterable {
        case requiredAttributes     // Check for required attributes
        case descriptiveText       // Check for meaningful labels/descriptions
        case contrastRatio         // Check color contrast
        case interactionSize       // Check touch target size
        case keyboardNavigation    // Check keyboard accessibility
        case hierarchyStructure    // Check element hierarchy
        case uniqueIdentifiers     // Check for unique identifiers
        case actionAvailability    // Check for available actions
        case customActions         // Check custom action implementation
        case groupingBehavior      // Check grouping and containers
    }
    
    /// Validation result
    struct ValidationResult {
        let type: RuleType
        let element: AccessibleElement
        let severity: Severity
        let message: String
        let suggestion: String?
        
        var isViolation: Bool {
            return severity != .pass
        }
    }
    
    /// Result severity
    enum Severity: String {
        case pass        // No issues found
        case info        // Informational suggestion
        case warning     // Potential issue
        case error       // Critical issue
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = AccessibilityValidator()
    
    /// Results publisher
    let resultsPublisher = PassthroughSubject<[ValidationResult], Never>()
    
    /// Active rules
    private(set) var activeRules: Set<RuleType> = Set(RuleType.allCases)
    
    // MARK: - Rule Management
    
    /// Enable validation rule
    func enableRule(_ rule: RuleType) {
        activeRules.insert(rule)
    }
    
    /// Disable validation rule
    func disableRule(_ rule: RuleType) {
        activeRules.remove(rule)
    }
    
    // MARK: - Validation
    
    /// Validate single element
    func validateElement(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Validate each active rule
        for rule in activeRules {
            switch rule {
            case .requiredAttributes:
                results += await validateRequiredAttributes(element)
            case .descriptiveText:
                results += await validateDescriptiveText(element)
            case .contrastRatio:
                results += await validateContrastRatio(element)
            case .interactionSize:
                results += await validateInteractionSize(element)
            case .keyboardNavigation:
                results += await validateKeyboardNavigation(element)
            case .hierarchyStructure:
                results += await validateHierarchyStructure(element)
            case .uniqueIdentifiers:
                results += await validateUniqueIdentifiers(element)
            case .actionAvailability:
                results += await validateActionAvailability(element)
            case .customActions:
                results += await validateCustomActions(element)
            case .groupingBehavior:
                results += await validateGroupingBehavior(element)
            }
        }
        
        return results
    }
    
    /// Validate element tree
    func validateElementTree(_ root: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Validate root element
        results += await validateElement(root)
        
        // Recursively validate children
        if let children = root.AXChildren as? [AccessibleElement] {
            for child in children {
                results += await validateElementTree(child)
            }
        }
        
        return results
    }
    
    // MARK: - Rule Implementations
    
    private func validateRequiredAttributes(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check role
        if element.AXRole == nil {
            results.append(ValidationResult(
                type: .requiredAttributes,
                element: element,
                severity: .error,
                message: "Missing required role attribute",
                suggestion: "Ensure element has a valid accessibility role"
            ))
        }
        
        // Check label/description
        if element.AXLabel == nil && element.AXDescription == nil && element.AXTitle == nil {
            results.append(ValidationResult(
                type: .requiredAttributes,
                element: element,
                severity: .warning,
                message: "Missing descriptive text",
                suggestion: "Add a label, description, or title to describe this element"
            ))
        }
        
        // Check value for controls
        if isControl(element) && element.AXValue == nil {
            results.append(ValidationResult(
                type: .requiredAttributes,
                element: element,
                severity: .warning,
                message: "Control missing value attribute",
                suggestion: "Add a value attribute to indicate control state"
            ))
        }
        
        return results
    }
    
    private func validateDescriptiveText(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check label quality
        if let label = element.AXLabel as? String {
            if label.count < 3 {
                results.append(ValidationResult(
                    type: .descriptiveText,
                    element: element,
                    severity: .warning,
                    message: "Label text is too short",
                    suggestion: "Use more descriptive label text"
                ))
            }
            if label.lowercased() == "button" || label.lowercased() == "label" {
                results.append(ValidationResult(
                    type: .descriptiveText,
                    element: element,
                    severity: .warning,
                    message: "Generic label text",
                    suggestion: "Use more specific label text that describes the element's purpose"
                ))
            }
        }
        
        // Check description quality
        if let description = element.AXDescription as? String {
            if description.count < 10 {
                results.append(ValidationResult(
                    type: .descriptiveText,
                    element: element,
                    severity: .info,
                    message: "Description text is brief",
                    suggestion: "Consider adding more detailed description"
                ))
            }
        }
        
        return results
    }
    
    private func validateContrastRatio(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check if element has text content
        if hasTextContent(element) {
            if let foreground = element.AXForegroundColor as? CGColor,
               let background = element.AXBackgroundColor as? CGColor {
                let ratio = calculateContrastRatio(foreground, background)
                
                // WCAG AA requires 4.5:1 for normal text
                if ratio < 4.5 {
                    results.append(ValidationResult(
                        type: .contrastRatio,
                        element: element,
                        severity: .error,
                        message: "Insufficient color contrast ratio (\(String(format: "%.1f", ratio)):1)",
                        suggestion: "Increase contrast ratio to at least 4.5:1 for normal text"
                    ))
                }
            }
        }
        
        return results
    }
    
    private func validateInteractionSize(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check if element is interactive
        if isInteractive(element) {
            if let size = element.AXSize as? CGSize {
                // WCAG target size minimum is 44x44 points
                if size.width < 44 || size.height < 44 {
                    results.append(ValidationResult(
                        type: .interactionSize,
                        element: element,
                        severity: .warning,
                        message: "Touch target size too small (\(Int(size.width))x\(Int(size.height)))",
                        suggestion: "Increase touch target size to at least 44x44 points"
                    ))
                }
            }
        }
        
        return results
    }
    
    private func validateKeyboardNavigation(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check keyboard accessibility
        if isInteractive(element) {
            if !element.AXEnabled ?? true {
                results.append(ValidationResult(
                    type: .keyboardNavigation,
                    element: element,
                    severity: .error,
                    message: "Interactive element not keyboard accessible",
                    suggestion: "Enable keyboard accessibility for this element"
                ))
            }
            
            // Check tab order
            if let tabIndex = element.AXTabIndex as? Int {
                if tabIndex < 0 {
                    results.append(ValidationResult(
                        type: .keyboardNavigation,
                        element: element,
                        severity: .warning,
                        message: "Element excluded from tab order",
                        suggestion: "Include element in natural tab order sequence"
                    ))
                }
            }
        }
        
        return results
    }
    
    private func validateHierarchyStructure(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check parent-child relationships
        if let children = element.AXChildren as? [AccessibleElement] {
            // Check for excessive nesting
            let depth = await calculateElementDepth(element)
            if depth > 10 {
                results.append(ValidationResult(
                    type: .hierarchyStructure,
                    element: element,
                    severity: .warning,
                    message: "Deep element nesting (depth: \(depth))",
                    suggestion: "Consider simplifying element hierarchy"
                ))
            }
            
            // Check for single-child containers
            if children.count == 1 {
                results.append(ValidationResult(
                    type: .hierarchyStructure,
                    element: element,
                    severity: .info,
                    message: "Container with single child element",
                    suggestion: "Consider merging or removing unnecessary container"
                ))
            }
        }
        
        return results
    }
    
    private func validateUniqueIdentifiers(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check identifier uniqueness
        if let identifier = element.AXIdentifier as? String {
            let siblings = await getSiblingElements(element)
            let duplicate = siblings.first { sibling in
                guard let siblingId = sibling.AXIdentifier as? String else { return false }
                return siblingId == identifier && sibling !== element
            }
            
            if duplicate != nil {
                results.append(ValidationResult(
                    type: .uniqueIdentifiers,
                    element: element,
                    severity: .error,
                    message: "Duplicate element identifier",
                    suggestion: "Use unique identifiers for all elements"
                ))
            }
        }
        
        return results
    }
    
    private func validateActionAvailability(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check required actions
        if isControl(element) {
            let hasPress = element.AXActions?.contains("AXPress") ?? false
            if !hasPress {
                results.append(ValidationResult(
                    type: .actionAvailability,
                    element: element,
                    severity: .warning,
                    message: "Control missing press action",
                    suggestion: "Add press action for control interaction"
                ))
            }
        }
        
        return results
    }
    
    private func validateCustomActions(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check custom action implementation
        if let actions = element.AXActions {
            let customActions = actions.filter { !isStandardAction($0) }
            
            for action in customActions {
                if !action.starts(with: "AX") {
                    results.append(ValidationResult(
                        type: .customActions,
                        element: element,
                        severity: .warning,
                        message: "Invalid custom action prefix",
                        suggestion: "Custom actions should start with 'AX' prefix"
                    ))
                }
            }
        }
        
        return results
    }
    
    private func validateGroupingBehavior(_ element: AccessibleElement) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Check group relationships
        if isGroup(element) {
            if let children = element.AXChildren as? [AccessibleElement] {
                // Check group size
                if children.count < 2 {
                    results.append(ValidationResult(
                        type: .groupingBehavior,
                        element: element,
                        severity: .info,
                        message: "Group with insufficient elements",
                        suggestion: "Groups should contain multiple related elements"
                    ))
                }
                
                // Check role consistency
                let roles = Set(children.compactMap { $0.AXRole })
                if roles.count > 1 {
                    results.append(ValidationResult(
                        type: .groupingBehavior,
                        element: element,
                        severity: .warning,
                        message: "Inconsistent roles in group",
                        suggestion: "Group elements should have consistent roles"
                    ))
                }
            }
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func isControl(_ element: AccessibleElement) -> Bool {
        guard let role = element.AXRole else { return false }
        return role.contains("Button") ||
               role.contains("TextField") ||
               role.contains("Slider") ||
               role.contains("Switch")
    }
    
    private func isInteractive(_ element: AccessibleElement) -> Bool {
        return isControl(element) ||
               (element.AXActions?.isEmpty == false)
    }
    
    private func hasTextContent(_ element: AccessibleElement) -> Bool {
        return element.AXValue as? String != nil ||
               element.AXTitle as? String != nil ||
               element.AXLabel as? String != nil
    }
    
    private func isGroup(_ element: AccessibleElement) -> Bool {
        guard let role = element.AXRole else { return false }
        return role.contains("Group") ||
               role.contains("List") ||
               role.contains("Grid")
    }
    
    private func isStandardAction(_ action: String) -> Bool {
        return ["AXPress", "AXIncrement", "AXDecrement", "AXConfirm", "AXCancel"].contains(action)
    }
    
    private func calculateContrastRatio(_ foreground: CGColor, _ background: CGColor) -> CGFloat {
        // Convert colors to luminance values
        let fg = relativeLuminance(foreground)
        let bg = relativeLuminance(background)
        
        // Calculate contrast ratio
        let lighter = max(fg, bg)
        let darker = min(fg, bg)
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private func relativeLuminance(_ color: CGColor) -> CGFloat {
        guard let components = color.components else { return 0 }
        let rgb = components.prefix(3)
        let sRGB = rgb.map { value in
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * sRGB[0] + 0.7152 * sRGB[1] + 0.0722 * sRGB[2]
    }
    
    private func calculateElementDepth(_ element: AccessibleElement) async -> Int {
        var depth = 0
        var current: AccessibleElement? = element
        
        while current?.AXParent != nil {
            depth += 1
            current = current?.AXParent
        }
        
        return depth
    }
    
    private func getSiblingElements(_ element: AccessibleElement) async -> [AccessibleElement] {
        guard let parent = element.AXParent,
              let siblings = parent.AXChildren as? [AccessibleElement] else {
            return []
        }
        return siblings
    }
}