import Foundation

/// The context passed to each skill during execution.
/// Contains all the services a skill might need, plus the current
/// conversation state and a way to emit events to the UI.
@MainActor
final class SkillExecutionContext {

    let httpClient: HTTPClient
    let secureKeyStore: SecureKeyStore
    let memoryStore: MemoryStore
    let logger: AppLogger

    // The current conversation messages (read-only for skills)
    let conversationMessages: [AgentMessage]

    // Callback for requesting user confirmation before sensitive actions
    let requestConfirmation: (ConfirmationRequest) async -> Bool

    // Callback for emitting events to the UI
    let emitEvent: (AgentEvent) -> Void

    init(
        httpClient: HTTPClient,
        secureKeyStore: SecureKeyStore,
        memoryStore: MemoryStore,
        logger: AppLogger,
        conversationMessages: [AgentMessage],
        requestConfirmation: @escaping (ConfirmationRequest) async -> Bool,
        emitEvent: @escaping (AgentEvent) -> Void
    ) {
        self.httpClient = httpClient
        self.secureKeyStore = secureKeyStore
        self.memoryStore = memoryStore
        self.logger = logger
        self.conversationMessages = conversationMessages
        self.requestConfirmation = requestConfirmation
        self.emitEvent = emitEvent
    }

    /// Convenience: request confirmation for a skill action.
    func confirm(skillName: String, action: String, description: String, arguments: JSONValue) async -> Bool {
        let request = ConfirmationRequest(
            skillName: skillName,
            action: action,
            description: description,
            arguments: arguments
        )
        emitEvent(.confirmationRequested(request))
        return await requestConfirmation(request)
    }
}
