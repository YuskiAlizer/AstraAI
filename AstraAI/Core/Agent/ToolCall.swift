import Foundation

/// A tool/function call requested by the AI model.
struct ToolCall: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var arguments: JSONValue
    var status: ToolCallStatus
    var result: String?
    var error: String?

    init(id: String, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.status = .pending
        self.result = nil
        self.error = nil
    }
}

enum ToolCallStatus: String, Codable, Sendable {
    case pending, executing, completed, failed, cancelled, awaitingConfirmation
}

/// A request for user confirmation before executing a sensitive action.
struct ConfirmationRequest: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let skillName: String
    let action: String
    let description: String
    var arguments: JSONValue

    init(id: UUID = UUID(), skillName: String, action: String, description: String, arguments: JSONValue) {
        self.id = id
        self.skillName = skillName
        self.action = action
        self.description = description
        self.arguments = arguments
    }
}

/// The state of a single agent run.
struct AgentRunState: Codable, Equatable {
    var iteration: Int
    var maxIterations: Int
    var isRunning: Bool
    var isCancelled: Bool
    var currentSkill: String?
    var statusText: String?

    static let defaultMaxIterations = 6

    static var initial: AgentRunState {
        AgentRunState(
            iteration: 0,
            maxIterations: defaultMaxIterations,
            isRunning: false,
            isCancelled: false,
            currentSkill: nil,
            statusText: nil
        )
    }
}
