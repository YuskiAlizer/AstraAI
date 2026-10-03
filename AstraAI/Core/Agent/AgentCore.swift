import Foundation
import SwiftUI
import Combine

/// The Agent Core is the brain of Astra AI.
/// It receives user input, sends it to the AI provider with tool definitions,
/// executes selected skills, feeds results back, and produces the final response.
///
/// Agent Loop:
///   USER INPUT → CONTEXT → MODEL → TOOL SELECTION → SKILL EXECUTION
///   → RESULT → MODEL → FINAL RESPONSE
///
/// The loop continues until the model produces a final response with no
/// further tool calls, or until maxIterations is reached.
@MainActor
final class AgentCore: ObservableObject {

    // Published state for UI
    @Published var runState: AgentRunState = .initial
    @Published var events: [AgentEvent] = []
    @Published var pendingConfirmation: ConfirmationRequest?
    @Published var activeToolCalls: [ToolCall] = []
    @Published var currentSources: [Source] = []
    @Published var streamingText: String = ""

    // Dependencies
    private let providerRegistry: AIProviderRegistry
    private let providerSettings: AIProviderSettings
    private let secureKeyStore: SecureKeyStore
    private let skillRegistry: SkillRegistry
    private let skillSettingsStore: SkillSettingsStore
    private let memoryStore: MemoryStore
    private let conversationStore: ConversationStore
    private let httpClient: HTTPClient
    private let logger: AppLogger

    // Cancellation
    private var currentTask: Task<Void, Never>?

    // Event stream for subscribers
    private let eventSubject = PassthroughSubject<AgentEvent, Never>()

    var eventPublisher: AnyPublisher<AgentEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    init(
        providerRegistry: AIProviderRegistry,
        providerSettings: AIProviderSettings,
        secureKeyStore: SecureKeyStore,
        skillRegistry: SkillRegistry,
        skillSettingsStore: SkillSettingsStore,
        memoryStore: MemoryStore,
        conversationStore: ConversationStore,
        httpClient: HTTPClient,
        logger: AppLogger
    ) {
        self.providerRegistry = providerRegistry
        self.providerSettings = providerSettings
        self.secureKeyStore = secureKeyStore
        self.skillRegistry = skillRegistry
        self.skillSettingsStore = skillSettingsStore
        self.memoryStore = memoryStore
        self.conversationStore = conversationStore
        self.httpClient = httpClient
        self.logger = logger
    }

    // MARK: - Public API

    /// Run the agent loop for a user message within a conversation.
    /// Returns the updated conversation.
    @discardableResult
    func run(userMessage: String, attachments: [Attachment] = [], conversation: Conversation) async -> Conversation {
        guard !runState.isRunning else {
            logger.warning("Agent already running, ignoring new request")
            return conversation
        }

        var updatedConversation = conversation

        // Reset state
        runState = .initial
        runState.isRunning = true
        events = []
        activeToolCalls = []
        currentSources = []
        streamingText = ""
        pendingConfirmation = nil

        // Add user message to conversation
        let userMsg = AgentMessage.user(userMessage, attachments: attachments)
        updatedConversation.messages.append(userMsg)
        updatedConversation.updatedAt = Date()

        emit(.started)
        emit(.statusChanged("Démarrage de l'agent..."))

        await executeAgentLoop(conversation: &updatedConversation)

        return updatedConversation
    }

    /// Cancel the current agent run.
    func cancel() {
        runState.isCancelled = true
        currentTask?.cancel()
        emit(.cancelled)
        emit(.statusChanged("Tâche annulée"))
        finalizeRun()
    }

    /// Respond to a pending confirmation request.
    func resolveConfirmation(_ request: ConfirmationRequest, approved: Bool) {
        pendingConfirmation = nil
        // The confirmation result is handled via the continuation in the loop
        confirmationResolvers[request.id]?(approved)
        confirmationResolvers.removeValue(forKey: request.id)
    }

    // MARK: - Agent Loop

    private func executeAgentLoop(conversation: inout Conversation) async {
        defer { finalizeRun() }

        // Build system prompt
        let systemPrompt = buildSystemPrompt()

        // Get enabled skills and their definitions for the provider
        let enabledSkills = skillRegistry.allSkills.filter { skill in
            skillSettingsStore.isEnabled(skillId: skill.id)
        }
        let toolDefinitions = enabledSkills.map { $0.toToolDefinition() }

        // Get the configured provider
        let providerId = providerSettings.selectedProviderId
        let modelId = providerSettings.selectedModelId(for: providerId)
        let apiKey = secureKeyStore.loadAPIKey(for: providerId) ?? ""

        guard !apiKey.isEmpty else {
            let msg = "Aucune clé API configurée pour le fournisseur \(providerId). Configurez-la dans les paramètres."
            emit(.error(msg))
            addAssistantMessage(msg, to: &conversation)
            return
        }

        guard let provider = providerRegistry.provider(for: providerId) else {
            let msg = "Fournisseur IA introuvable: \(providerId). Vérifiez les paramètres."
            emit(.error(msg))
            addAssistantMessage(msg, to: &conversation)
            return
        }
        let settings = AIProviderConfig(
            providerId: providerId,
            model: modelId,
            apiKey: apiKey,
            endpoint: providerSettings.customEndpoint(for: providerId),
            maxTokens: 4096,
            temperature: 0.7
        )

        // Build the message list for the provider
        var messages: [ProviderMessage] = [.system(systemPrompt)]

        // Add relevant memories as context
        let relevantMemories = memoryStore.search(query: conversation.lastUserMessage ?? "")
        if !relevantMemories.isEmpty {
            let memoryContext = relevantMemories.map { "- \($0.category)/\($0.key): \($0.value)" }.joined(separator: "\n")
            messages.append(.system("Souvenirs pertinents:\n\(memoryContext)"))
        }

        // Add conversation messages
        for msg in conversation.messages {
            switch msg.role {
            case .system:
                // Already handled above
                continue
            case .user:
                messages.append(.user(msg.content))
            case .assistant:
                messages.append(.assistant(msg.content))
            case .tool:
                if let toolName = msg.toolName, let toolCallId = msg.toolCallId {
                    messages.append(.toolResult(name: toolName, toolCallId: toolCallId, content: msg.content))
                }
            }
        }

        // Agent loop
        while runState.iteration < runState.maxIterations && !runState.isCancelled {
            runState.iteration += 1
            emit(.iterationCompleted(iteration: runState.iteration, maxIterations: runState.maxIterations))

            // Call the AI provider
            emit(.statusChanged("Réflexion..."))

            let request = AIRequest(
                messages: messages,
                tools: toolDefinitions,
                model: settings.model,
                temperature: settings.temperature,
                maxTokens: settings.maxTokens,
                stream: true
            )

            do {
                let response = try await callProvider(
                    provider: provider,
                    settings: settings,
                    request: request
                )

                // If there's a text response, stream it
                if !response.content.isEmpty {
                    emit(.statusChanged("Génération de la réponse..."))
                    streamingText = response.content
                    emit(.streamingComplete)
                }

                // If there are tool calls, execute them
                if response.toolCalls.isEmpty {
                    // No more tool calls — we're done
                    let assistantMsg = AgentMessage.assistant(response.content, sources: currentSources)
                    conversation.messages.append(assistantMsg)
                    conversation.updatedAt = Date()
                    emit(.taskCompleted)
                    emit(.statusChanged("Terminé"))
                    break
                }

                // Add assistant message with tool calls to conversation
                let assistantWithTools = AgentMessage(
                    role: .assistant,
                    content: response.content,
                    toolCalls: response.toolCalls
                )
                conversation.messages.append(assistantWithTools)
                messages.append(.assistant(response.content))

                // Execute each tool call
                for toolCall in response.toolCalls {
                    if runState.isCancelled { break }

                    let result = await executeToolCall(toolCall, conversation: &conversation)
                    messages.append(.toolResult(
                        name: toolCall.name,
                        toolCallId: toolCall.id,
                        content: result
                    ))
                }

            } catch {
                let errorMsg = "Erreur du fournisseur IA: \(error.localizedDescription)"
                logger.error(errorMsg)
                emit(.error(errorMsg))
                emit(.statusChanged("Erreur"))

                // Add error message and stop
                let errorMsg2 = "Désolé, une erreur est survenue: \(error.localizedDescription)"
                let assistantMsg = AgentMessage.assistant(errorMsg2)
                conversation.messages.append(assistantMsg)
                break
            }
        }

        // Check if we hit max iterations
        if runState.iteration >= runState.maxIterations && !runState.isCancelled {
            let msg = "Limite d'itérations atteinte (\(runState.maxIterations)). La tâche pourrait être incomplète."
            logger.warning(msg)
            emit(.statusChanged("Limite d'itérations atteinte"))
        }

        // Persist conversation
        do {
            try conversationStore.saveConversation(conversation)
        } catch {
            logger.error("Failed to save conversation: \(error)")
        }
    }

    // MARK: - Tool Execution

    private func executeToolCall(_ toolCall: ToolCall, conversation: inout Conversation) async -> String {
        emit(.skillSelected(name: toolCall.name, arguments: toolCall.arguments.jsonString()))
        emit(.statusChanged("Exécution: \(toolCall.name)..."))

        guard let skill = skillRegistry.skill(id: toolCall.name) else {
            let error = "Skill inconnu: \(toolCall.name)"
            emit(.skillFailed(name: toolCall.name, error: error))
            return error
        }

        // Check if skill is enabled
        guard skillSettingsStore.isEnabled(skillId: skill.id) else {
            let error = "Le skill \(skill.name) est désactivé. Activez-le dans les paramètres."
            emit(.skillFailed(name: toolCall.name, error: error))
            return error
        }

        // Check if the skill requires confirmation
        if skill.requiresConfirmation(for: toolCall.arguments) {
            let confirmed = await skillExecutionContext().confirm(
                skillName: skill.name,
                action: toolCall.name,
                description: skill.confirmationDescription(for: toolCall.arguments),
                arguments: toolCall.arguments
            )
            if !confirmed {
                let msg = "Action annulée par l'utilisateur."
                emit(.skillFailed(name: toolCall.name, error: msg))
                return msg
            }
        }

        emit(.skillExecuting(name: toolCall.name))

        let context = skillExecutionContext()

        do {
            let result = try await skill.execute(input: toolCall.arguments, context: context)

            let summary = result.summary ?? "Terminé"
            emit(.skillCompleted(name: toolCall.name, resultSummary: summary))

            // Update sources if provided
            if !result.sources.isEmpty {
                currentSources.append(contentsOf: result.sources)
                emit(.sourcesUpdated(currentSources))
            }

            // Add tool result message to conversation
            let toolMsg = AgentMessage.tool(name: toolCall.name, result: result.output.jsonString(), toolCallId: toolCall.id)
            conversation.messages.append(toolMsg)

            return result.output.jsonString()

        } catch {
            let errorMsg = error.localizedDescription
            emit(.skillFailed(name: toolCall.name, error: errorMsg))
            return "{\"error\": \"\(errorMsg)\"}"
        }
    }

    // MARK: - Provider Call (with streaming)

    private func callProvider(
        provider: any AIProvider,
        settings: AIProviderConfig,
        request: AIRequest
    ) async throws -> AIResponse {

        var content = ""
        var toolCalls: [ToolCall] = []

        for try await event in provider.stream(request, config: settings) {
            if runState.isCancelled {
                throw CancellationError()
            }

            switch event {
            case .textChunk(let chunk):
                content += chunk
                streamingText = content
                emit(.streamingChunk(chunk))
            case .toolCall(let call):
                toolCalls.append(call)
            case .done:
                emit(.streamingComplete)
            }
        }

        return AIResponse(content: content, toolCalls: toolCalls)
    }

    // MARK: - System Prompt

    private func buildSystemPrompt() -> String {
        let enabledSkills = skillRegistry.allSkills.filter {
            skillSettingsStore.isEnabled(skillId: $0.id)
        }

        let skillList = enabledSkills.map { skill in
            "- \(skill.name): \(skill.description)"
        }.joined(separator: "\n")

        let currentDate = ISO8601DateFormatter().string(from: Date())

        return """
        Tu es Astra AI, un assistant personnel intelligent et proactif.
        Tu aides l'utilisateur à accomplir des tâches en utilisant les outils disponibles.
        Date actuelle: \(currentDate)

        Règles:
        1. Utilise les outils disponibles lorsque nécessaire pour accomplir les tâches.
        2. Sois concis et précis dans tes réponses.
        3. Cite tes sources lorsque tu utilises des informations externes.
        4. Demande confirmation avant d'effectuer des actions sensibles.
        5. Si une tâche n'est pas possible, explique pourquoi et propose une alternative.
        6. Ne prétends pas avoir accès à des données que tu n'as pas.

        Outils disponibles:
        \(skillList)
        """
    }

    // MARK: - Helpers

    private var confirmationResolvers: [UUID: (Bool) -> Void] = [:]

    private func skillExecutionContext() -> SkillExecutionContext {
        let lastMessages = Array(events.suffix(10))

        return SkillExecutionContext(
            httpClient: httpClient,
            secureKeyStore: secureKeyStore,
            memoryStore: memoryStore,
            logger: logger,
            conversationMessages: [], // Will be set by the loop
            requestConfirmation: { [weak self] request in
                guard let self = self else { return false }
                return await withCheckedContinuation { continuation in
                    self.pendingConfirmation = request
                    self.confirmationResolvers[request.id] = { approved in
                        continuation.resume(returning: approved)
                    }
                }
            },
            emitEvent: { [weak self] event in
                self?.emit(event)
            }
        )
    }

    private func emit(_ event: AgentEvent) {
        events.append(event)
        logger.info(event.logDescription)
        eventSubject.send(event)
    }

    private func finalizeRun() {
        runState.isRunning = false
        runState.currentSkill = nil
        runState.statusText = nil
        currentTask = nil
    }

    private func addAssistantMessage(_ text: String, to conversation: inout Conversation) {
        let msg = AgentMessage.assistant(text)
        conversation.messages.append(msg)
        do {
            try conversationStore.saveConversation(conversation)
        } catch {
            logger.error("Failed to save conversation: \(error)")
        }
    }
}
