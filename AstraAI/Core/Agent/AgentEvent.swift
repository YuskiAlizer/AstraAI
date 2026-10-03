import Foundation

/// Events emitted by the Agent Core during execution.
/// The UI observes these to show real-time status and progress.
enum AgentEvent {
    case started
    case skillSelected(name: String, arguments: String)
    case skillExecuting(name: String)
    case skillCompleted(name: String, resultSummary: String)
    case skillFailed(name: String, error: String)
    case confirmationRequested(ConfirmationRequest)
    case streamingChunk(String)
    case streamingComplete
    case sourcesUpdated([Source])
    case statusChanged(String)
    case iterationCompleted(iteration: Int, maxIterations: Int)
    case taskCompleted
    case cancelled
    case error(String)

    var logDescription: String {
        switch self {
        case .started:
            return "Agent started"
        case .skillSelected(let name, _):
            return "→ Skill selected: \(name)"
        case .skillExecuting(let name):
            return "→ Executing skill: \(name)"
        case .skillCompleted(let name, let summary):
            return "→ Skill completed: \(name) — \(summary.prefix(80))"
        case .skillFailed(let name, let error):
            return "→ Skill failed: \(name) — \(error)"
        case .confirmationRequested(let req):
            return "→ Confirmation requested for: \(req.skillName)/\(req.action)"
        case .streamingChunk(let chunk):
            return "→ Streaming chunk: \(chunk.prefix(40))..."
        case .streamingComplete:
            return "→ Streaming complete"
        case .sourcesUpdated(let sources):
            return "→ Sources updated: \(sources.count) source(s)"
        case .statusChanged(let status):
            return "→ Status: \(status)"
        case .iterationCompleted(let iter, let max):
            return "→ Iteration \(iter)/\(max) completed"
        case .taskCompleted:
            return "→ Task completed"
        case .cancelled:
            return "→ Cancelled"
        case .error(let msg):
            return "→ Error: \(msg)"
        }
    }
}
