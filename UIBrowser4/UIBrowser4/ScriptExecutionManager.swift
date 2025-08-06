import Cocoa

/// Manages AppleScript execution and recording
@MainActor
final class ScriptExecutionManager {
    // MARK: - Types
    
    /// Script execution result
    struct ExecutionResult {
        let script: String
        let output: String?
        let error: Error?
        let duration: TimeInterval
        let timestamp: Date
    }
    
    /// Script recording
    struct ScriptRecording {
        let name: String
        let description: String
        let script: String
        let steps: [RecordingStep]
        let timestamp: Date
        
        struct RecordingStep {
            let element: AccessibleElement
            let action: String
            let parameters: [String: Any]
            let timestamp: Date
        }
    }
    
    /// Execution options
    struct ExecutionOptions {
        var timeout: TimeInterval = 30.0
        var showProgress: Bool = true
        var pauseOnError: Bool = true
        var logOutput: Bool = true
    }
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = ScriptExecutionManager()
    
    /// Execution history
    private var executionHistory: [ExecutionResult] = []
    
    /// Active recordings
    private var activeRecordings: [String: ScriptRecording] = [:]
    
    /// Current recording name
    private var currentRecording: String?
    
    /// Execution observers
    private var executionObservers: [UUID: (ExecutionResult) -> Void] = [:]
    
    /// Publishers
    let executionStartedPublisher = PassthroughSubject<String, Never>()
    let executionCompletedPublisher = PassthroughSubject<ExecutionResult, Never>()
    let recordingStartedPublisher = PassthroughSubject<String, Never>()
    let recordingCompletedPublisher = PassthroughSubject<ScriptRecording, Never>()
    
    // MARK: - Script Execution
    
    /// Execute AppleScript
    func executeScript(
        _ script: String,
        options: ExecutionOptions = ExecutionOptions()
    ) async throws -> ExecutionResult {
        let startTime = Date()
        
        // Notify start
        executionStartedPublisher.send(script)
        
        // Create progress if needed
        let progress = options.showProgress ? ProgressReporter("Executing Script") : nil
        progress?.start()
        
        do {
            // Create script
            let appleScript = NSAppleScript(source: script)
            var errorInfo: NSDictionary?
            
            // Execute with timeout
            let output = try await withTimeout(options.timeout) {
                appleScript?.executeAndReturnError(&errorInfo)
            }
            
            // Check for errors
            if let error = errorInfo {
                throw ScriptError.executionFailed(error)
            }
            
            // Create result
            let result = ExecutionResult(
                script: script,
                output: output?.stringValue,
                error: nil,
                duration: Date().timeIntervalSince(startTime),
                timestamp: startTime
            )
            
            // Add to history
            executionHistory.append(result)
            
            // Log if needed
            if options.logOutput {
                logExecution(result)
            }
            
            // Notify completion
            executionCompletedPublisher.send(result)
            
            return result
            
        } catch {
            // Create error result
            let result = ExecutionResult(
                script: script,
                output: nil,
                error: error,
                duration: Date().timeIntervalSince(startTime),
                timestamp: startTime
            )
            
            // Add to history
            executionHistory.append(result)
            
            // Log error
            logExecution(result)
            
            // Notify completion
            executionCompletedPublisher.send(result)
            
            throw error
        } finally {
            progress?.complete()
        }
    }
    
    /// Add execution observer
    func addExecutionObserver(
        _ observer: @escaping (ExecutionResult) -> Void
    ) -> UUID {
        let id = UUID()
        executionObservers[id] = observer
        return id
    }
    
    /// Remove execution observer
    func removeExecutionObserver(_ id: UUID) {
        executionObservers.removeValue(forKey: id)
    }
    
    // MARK: - Script Recording
    
    /// Start recording
    func startRecording(name: String, description: String = "") {
        // Stop any active recording
        stopRecording()
        
        // Create new recording
        let recording = ScriptRecording(
            name: name,
            description: description,
            script: "",
            steps: [],
            timestamp: Date()
        )
        
        activeRecordings[name] = recording
        currentRecording = name
        
        // Notify start
        recordingStartedPublisher.send(name)
    }
    
    /// Record step
    func recordStep(
        element: AccessibleElement,
        action: String,
        parameters: [String: Any] = [:]
    ) {
        guard let name = currentRecording,
              var recording = activeRecordings[name] else {
            return
        }
        
        // Create step
        let step = ScriptRecording.RecordingStep(
            element: element,
            action: action,
            parameters: parameters,
            timestamp: Date()
        )
        
        // Add to recording
        recording.steps.append(step)
        activeRecordings[name] = recording
    }
    
    /// Stop recording
    func stopRecording() -> ScriptRecording? {
        guard let name = currentRecording,
              let recording = activeRecordings[name] else {
            return nil
        }
        
        // Remove recording
        activeRecordings.removeValue(forKey: name)
        currentRecording = nil
        
        // Generate script
        Task {
            // Generate script from steps
            var script = """
                -- Generated by UI Browser 4
                -- Recording: \(recording.name)
                -- Date: \(formatDate(recording.timestamp))
                -- Description: \(recording.description)
                
                """
            
            for step in recording.steps {
                if let stepScript = try? await generateStepScript(step) {
                    script += "\n\(stepScript)"
                }
            }
            
            // Update recording
            var updatedRecording = recording
            updatedRecording.script = script
            
            // Notify completion
            recordingCompletedPublisher.send(updatedRecording)
        }
        
        return recording
    }
    
    /// Generate script for recording step
    private func generateStepScript(
        _ step: ScriptRecording.RecordingStep
    ) async throws -> String {
        // Use template manager to generate script
        let style = AppleScriptTemplateManager.GenerationStyle(
            includeComments: true,
            useNumericIndices: false,
            indentWithTabs: false,
            addErrorHandling: false
        )
        
        return try await AppleScriptTemplateManager.shared.generateScript(
            for: step.element,
            type: .systemEvents,
            style: style
        )
    }
    
    // MARK: - History Management
    
    /// Get execution history
    func getExecutionHistory() -> [ExecutionResult] {
        return executionHistory
    }
    
    /// Clear execution history
    func clearExecutionHistory() {
        executionHistory.removeAll()
    }
    
    /// Save execution history
    func saveExecutionHistory() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        let data = try encoder.encode(executionHistory)
        try data.write(to: historyURL)
    }
    
    /// Load execution history
    func loadExecutionHistory() throws {
        let data = try Data(contentsOf: historyURL)
        executionHistory = try PropertyListDecoder().decode([ExecutionResult].self, from: data)
    }
    
    // MARK: - Helpers
    
    private func withTimeout<T>(
        _ seconds: TimeInterval,
        operation: () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ScriptError.timeout
            }
            
            // Add operation task
            group.addTask {
                return try await operation()
            }
            
            // Return first completed result
            return try await group.next() ?? { throw ScriptError.timeout }()
        }
    }
    
    private func logExecution(_ result: ExecutionResult) {
        let status = result.error == nil ? "SUCCESS" : "FAILURE"
        let duration = String(format: "%.2f", result.duration)
        
        print("""
            Script Execution [\(status)] - \(formatDate(result.timestamp))
            Duration: \(duration)s
            Output: \(result.output ?? "none")
            Error: \(result.error?.localizedDescription ?? "none")
            """)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private var historyURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("UI Browser 4")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("ScriptHistory.plist")
    }
}

// MARK: - Supporting Types

/// Script execution errors
enum ScriptError: LocalizedError {
    case timeout
    case executionFailed(NSDictionary)
    case invalidScript
    case recordingNotFound
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Script execution timed out"
        case .executionFailed(let info):
            return info["NSAppleScriptErrorMessage"] as? String ?? "Script execution failed"
        case .invalidScript:
            return "Invalid script"
        case .recordingNotFound:
            return "Recording not found"
        }
    }
}

/// Progress reporting helper
private class ProgressReporter {
    let title: String
    var progress: Progress?
    
    init(_ title: String) {
        self.title = title
    }
    
    func start() {
        progress = Progress(totalUnitCount: 1)
        progress?.localizedDescription = title
        progress?.localizedAdditionalDescription = "Running script..."
        progress?.becomeCurrent(withPendingUnitCount: 1)
    }
    
    func complete() {
        progress?.completedUnitCount = 1
        progress?.resignCurrent()
    }
}