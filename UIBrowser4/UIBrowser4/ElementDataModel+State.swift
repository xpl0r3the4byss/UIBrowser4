import Foundation
import Combine

// MARK: - State Management Extensions
extension ElementDataModel {
    /// Current element state
    struct ElementState {
        var currentElement: AccessibleElement?
        var currentPath: NSIndexPath?
        var isLoading: Bool
        var error: Error?
    }
    
    /// State publisher
    static let statePublisher = CurrentValueSubject<ElementState, Never>(
        ElementState(currentElement: nil, currentPath: nil, isLoading: false, error: nil)
    )
    
    /// Update state with loading status
    @MainActor
    func setLoading(_ isLoading: Bool) {
        var state = Self.statePublisher.value
        state.isLoading = isLoading
        Self.statePublisher.send(state)
    }
    
    /// Update state with error
    @MainActor
    func setError(_ error: Error?) {
        var state = Self.statePublisher.value
        state.error = error
        Self.statePublisher.send(state)
    }
    
    /// Update state with new element
    @MainActor
    func setCurrentElement(_ element: AccessibleElement?, path: NSIndexPath?) {
        var state = Self.statePublisher.value
        state.currentElement = element
        state.currentPath = path
        state.error = nil
        Self.statePublisher.send(state)
    }
}