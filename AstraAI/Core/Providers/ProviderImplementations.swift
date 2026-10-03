import Foundation

/// OpenAI provider using the OpenAI Chat Completions API.
final class OpenAIProviderImpl: @unchecked Sendable {

    static let shared = make()

    private static func make() -> OpenAIProvider {
        let type = AIProviderType.openAI
        return OpenAIProvider(
            id: type.rawValue,
            displayName: type.displayName,
            models: type.models,
            defaultModel: type.models.first?.id
        )
    }
}

/// Anthropic provider using the Messages API.
/// Note: Anthropic uses a different API format, but for simplicity and
/// compatibility, we use the OpenAI-compatible interface where possible.
/// For full Anthropic API support, a dedicated implementation would be needed.
final class AnthropicProviderImpl: @unchecked Sendable {

    static let shared = make()

    private static func make() -> OpenAIProvider {
        let type = AIProviderType.anthropic
        return OpenAIProvider(
            id: type.rawValue,
            displayName: type.displayName,
            models: type.models,
            defaultModel: type.models.first?.id
        )
    }
}

/// Google Gemini provider.
/// Uses the OpenAI-compatible endpoint provided by Google.
final class GoogleProviderImpl: @unchecked Sendable {

    static let shared = make()

    private static func make() -> OpenAIProvider {
        let type = AIProviderType.google
        return OpenAIProvider(
            id: type.rawValue,
            displayName: type.displayName,
            models: type.models,
            defaultModel: type.models.first?.id
        )
    }
}

/// NVIDIA provider using the NVIDIA API catalog (OpenAI-compatible).
final class NVIDIAProviderImpl: @unchecked Sendable {

    static let shared = make()

    private static func make() -> OpenAIProvider {
        let type = AIProviderType.nvidia
        return OpenAIProvider(
            id: type.rawValue,
            displayName: type.displayName,
            models: type.models,
            defaultModel: type.models.first?.id
        )
    }
}

/// Local provider using Ollama (OpenAI-compatible API).
/// No API key required for local usage.
final class LocalProviderImpl: @unchecked Sendable {

    static let shared = make()

    private static func make() -> OpenAIProvider {
        let type = AIProviderType.local
        return OpenAIProvider(
            id: type.rawValue,
            displayName: type.displayName,
            models: type.models,
            defaultModel: type.models.first?.id
        )
    }
}

// MARK: - Convenience Registration

extension AIProviderRegistry {
    func register(_ type: AIProviderType) {
        let provider: OpenAIProvider
        switch type {
        case .openAI:
            provider = OpenAIProviderImpl.shared
        case .anthropic:
            provider = AnthropicProviderImpl.shared
        case .google:
            provider = GoogleProviderImpl.shared
        case .nvidia:
            provider = NVIDIAProviderImpl.shared
        case .local:
            provider = LocalProviderImpl.shared
        }
        register(provider)
    }
}
