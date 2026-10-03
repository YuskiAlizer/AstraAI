import Foundation

/// A provider-agnostic AI completion request.
struct AIRequest: Sendable {
    let messages: [ProviderMessage]
    let tools: [ToolDefinition]
    let model: String
    let temperature: Double
    let maxTokens: Int
    let stream: Bool
}

/// A message in the format expected by AI providers.
enum ProviderMessage: Sendable {
    case system(String)
    case user(String)
    case assistant(String)
    case toolResult(name: String, toolCallId: String, content: String)

    var role: String {
        switch self {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        case .toolResult: return "tool"
        }
    }

    var content: String {
        switch self {
        case .system(let s): return s
        case .user(let s): return s
        case .assistant(let s): return s
        case .toolResult(_, _, let s): return s
        }
    }
}

/// A response from an AI provider.
struct AIResponse: Sendable {
    let content: String
    let toolCalls: [ToolCall]
}

/// Streaming events from a provider.
enum AIStreamEvent: Sendable {
    case textChunk(String)
    case toolCall(ToolCall)
    case done
}

/// Configuration for a specific provider call.
struct AIProviderConfig: Sendable {
    let providerId: String
    let model: String
    let apiKey: String
    let endpoint: String?
    let maxTokens: Int
    let temperature: Double
}

/// The protocol that all AI providers must conform to.
protocol AIProvider: AnyObject, Sendable {
    var id: String { get }
    var displayName: String { get }
    var availableModels: [AIModel] { get }
    var defaultModel: String { get }

    /// Non-streaming completion.
    func complete(_ request: AIRequest, config: AIProviderConfig) async throws -> AIResponse

    /// Streaming completion.
    func stream(_ request: AIRequest, config: AIProviderConfig) -> AsyncThrowingStream<AIStreamEvent, Error>
}

/// A model offered by a provider.
struct AIModel: Identifiable, Equatable, Sendable, Hashable {
    let id: String
    let name: String
    let supportsToolCalling: Bool
    let supportsVision: Bool

    init(id: String, name: String, supportsToolCalling: Bool = true, supportsVision: Bool = false) {
        self.id = id
        self.name = name
        self.supportsToolCalling = supportsToolCalling
        self.supportsVision = supportsVision
    }
}

/// A tool/function definition sent to the AI provider.
struct ToolDefinition: Codable, Sendable, Equatable {
    let name: String
    let description: String
    let parameters: JSONValue
}
