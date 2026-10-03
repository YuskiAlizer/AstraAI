import Foundation
import SwiftUI

/// Registry that holds all registered AI providers and their configurations.
@MainActor
final class AIProviderRegistry: ObservableObject {

    @Published private(set) var providers: [String: any AIProvider] = [:]

    func register(_ provider: any AIProvider) {
        providers[provider.id] = provider
    }

    func provider(for id: String) -> (any AIProvider)? {
        providers[id]
    }

    var allProviders: [any AIProvider] {
        Array(providers.values)
    }

    func providerIds() -> [String] {
        Array(providers.keys).sorted()
    }
}

/// Available provider types.
enum AIProviderType: String, CaseIterable, Sendable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case nvidia = "nvidia"
    case local = "local"

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic (Claude)"
        case .google: return "Google (Gemini)"
        case .nvidia: return "NVIDIA"
        case .local: return "Local (Ollama)"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .google: return "https://generativelanguage.googleapis.com/v1beta"
        case .nvidia: return "https://integrate.api.nvidia.com/v1"
        case .local: return "http://localhost:11434"
        }
    }

    var apiKeyName: String {
        switch self {
        case .openAI: return "OpenAI API Key"
        case .anthropic: return "Anthropic API Key"
        case .google: return "Google API Key"
        case .nvidia: return "NVIDIA API Key"
        case .local: return "Ollama (no key needed)"
        }
    }

    var models: [AIModel] {
        switch self {
        case .openAI:
            return [
                AIModel(id: "gpt-4o", name: "GPT-4o", supportsToolCalling: true, supportsVision: true),
                AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", supportsToolCalling: true, supportsVision: true),
                AIModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", supportsToolCalling: true, supportsVision: true)
            ]
        case .anthropic:
            return [
                AIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", supportsToolCalling: true, supportsVision: true),
                AIModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", supportsToolCalling: true, supportsVision: true)
            ]
        case .google:
            return [
                AIModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", supportsToolCalling: true, supportsVision: true),
                AIModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", supportsToolCalling: true, supportsVision: true)
            ]
        case .nvidia:
            return [
                AIModel(id: "meta/llama-3.1-405b-instruct", name: "Llama 3.1 405B", supportsToolCalling: true, supportsVision: false),
                AIModel(id: "meta/llama-3.1-70b-instruct", name: "Llama 3.1 70B", supportsToolCalling: true, supportsVision: false)
            ]
        case .local:
            return [
                AIModel(id: "llama3.1", name: "Llama 3.1 (local)", supportsToolCalling: true, supportsVision: false),
                AIModel(id: "qwen2.5", name: "Qwen 2.5 (local)", supportsToolCalling: true, supportsVision: false)
            ]
        }
    }
}

/// Extension to make AIProviderType conform to AIProvider protocol via wrapper.
extension AIProviderType {
    var id: String { rawValue }
}

// MARK: - Provider Implementations

/// OpenAI-compatible provider (also works for NVIDIA and local Ollama with OpenAI-compatible API).
final class OpenAIProvider: AIProvider, @unchecked Sendable {

    let id: String
    let displayName: String
    let availableModels: [AIModel]
    let defaultModel: String
    private let httpClient: HTTPClient

    init(id: String = "openai", displayName: String = "OpenAI", models: [AIModel], defaultModel: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.availableModels = models
        self.defaultModel = defaultModel ?? models.first?.id ?? ""
        self.httpClient = HTTPClient()
    }

    func complete(_ request: AIRequest, config: AIProviderConfig) async throws -> AIResponse {
        let endpoint = config.endpoint ?? AIProviderType.openAI.defaultEndpoint
        let url = "\(endpoint)/chat/completions"

        var body: [String: Any] = [
            "model": config.model,
            "messages": request.messages.map { msg -> [String: Any] in
                switch msg {
                case .system(let s):
                    return ["role": "system", "content": s]
                case .user(let s):
                    return ["role": "user", "content": s]
                case .assistant(let s):
                    return ["role": "assistant", "content": s]
                case .toolResult(let name, let toolCallId, let content):
                    return [
                        "role": "tool",
                        "name": name,
                        "tool_call_id": toolCallId,
                        "content": content
                    ]
                }
            },
            "temperature": config.temperature,
            "max_tokens": config.maxTokens
        ]

        if !request.tools.isEmpty {
            body["tools"] = request.tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": jsonValueToAny(tool.parameters)
                    ]
                ]
            }
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(config.apiKey)"
        ]
        if id == "anthropic" {
            headers["x-api-key"] = config.apiKey
            headers["anthropic-version"] = "2023-06-01"
        }

        let response = try await httpClient.post(url, body: bodyData, headers: headers)

        guard response.isSuccess else {
            throw HTTPError.httpError(statusCode: response.statusCode, body: response.body)
        }

        return try parseOpenAIResponse(response.data)
    }

    func stream(_ request: AIRequest, config: AIProviderConfig) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let endpoint = config.endpoint ?? AIProviderType.openAI.defaultEndpoint
        let url = "\(endpoint)/chat/completions"

        var body: [String: Any] = [
            "model": config.model,
            "messages": request.messages.map { msg -> [String: Any] in
                switch msg {
                case .system(let s):
                    return ["role": "system", "content": s]
                case .user(let s):
                    return ["role": "user", "content": s]
                case .assistant(let s):
                    return ["role": "assistant", "content": s]
                case .toolResult(let name, let toolCallId, let content):
                    return [
                        "role": "tool",
                        "name": name,
                        "tool_call_id": toolCallId,
                        "content": content
                    ]
                }
            },
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
            "stream": true
        ]

        if !request.tools.isEmpty {
            body["tools"] = request.tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": jsonValueToAny(tool.parameters)
                    ]
                ]
            }
        }

        let bodyData = try? JSONSerialization.data(withJSONObject: body)

        var headers: [String: String] = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(config.apiKey)"
        ]
        if id == "anthropic" {
            headers["x-api-key"] = config.apiKey
            headers["anthropic-version"] = "2023-06-01"
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: url), let bodyData = bodyData else {
                        continuation.finish(throwing: HTTPError.invalidURL)
                        return
                    }
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.httpBody = bodyData
                    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: HTTPError.invalidResponse)
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))
                        if data == "[DONE]" {
                            continuation.yield(.done)
                            break
                        }

                        guard let lineData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let choice = choices.first else { continue }

                        let delta = choice["delta"] as? [String: Any] ?? [:]

                        if let content = delta["content"] as? String, !content.isEmpty {
                            continuation.yield(.textChunk(content))
                        }

                        if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                            for tc in toolCalls {
                                if let function = tc["function"] as? [String: Any],
                                   let name = function["name"] as? String {
                                    let callId = tc["id"] as? String ?? UUID().uuidString
                                    let argsStr = function["arguments"] as? String ?? "{}"
                                    let args = JSONValue.from(jsonString: argsStr) ?? .null
                                    continuation.yield(.toolCall(ToolCall(id: callId, name: name, arguments: args)))
                                }
                            }
                        }
                    }

                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Response Parsing

    private func parseOpenAIResponse(_ data: Data) throws -> AIResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let choice = choices.first else {
            throw AIProviderError.invalidResponse
        }

        let message = choice["message"] as? [String: Any] ?? [:]
        let content = message["content"] as? String ?? ""

        var toolCalls: [ToolCall] = []
        if let rawToolCalls = message["tool_calls"] as? [[String: Any]] {
            for tc in rawToolCalls {
                guard let function = tc["function"] as? [String: Any],
                      let name = function["name"] as? String else { continue }
                let callId = tc["id"] as? String ?? UUID().uuidString
                let argsStr = function["arguments"] as? String ?? "{}"
                let args = JSONValue.from(jsonString: argsStr) ?? .null
                toolCalls.append(ToolCall(id: callId, name: name, arguments: args))
            }
        }

        return AIResponse(content: content, toolCalls: toolCalls)
    }
}

enum AIProviderError: LocalizedError {
    case invalidResponse
    case missingAPIKey
    case unsupportedFeature(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse invalide du fournisseur IA"
        case .missingAPIKey:
            return "Clé API manquante. Configurez-la dans les paramètres."
        case .unsupportedFeature(let feature):
            return "Fonctionnalité non supportée: \(feature)"
        }
    }
}

// MARK: - Helpers

private func jsonValueToAny(_ json: JSONValue) -> Any {
    switch json {
    case .null: return NSNull()
    case .bool(let b): return b
    case .number(let n): return n
    case .string(let s): return s
    case .array(let arr): return arr.map { jsonValueToAny($0) }
    case .object(let dict):
        var result: [String: Any] = [:]
        for (k, v) in dict { result[k] = jsonValueToAny(v) }
        return result
    }
}
