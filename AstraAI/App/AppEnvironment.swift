import SwiftUI
import Combine

@MainActor
final class AppEnvironment: ObservableObject {

    // Published state
    @Published var theme: AppTheme = .system
    @Published var selectedTab: AppTab = .chat

    // Core services
    let logger: AppLogger
    let conversationStore: ConversationStore
    let memoryStore: MemoryStore
    let secureKeyStore: SecureKeyStore
    let skillSettingsStore: SkillSettingsStore
    let skillRegistry: SkillRegistry
    let providerRegistry: AIProviderRegistry
    let providerSettings: AIProviderSettings
    let agentCore: AgentCore

    // UI state
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?

    init() {
        let logger = AppLogger.shared
        self.logger = logger

        let fileManager = FileManager.default
        let appSupport = fileManager.applicationSupportDirectory

        let conversationStore = ConversationStore(
            directory: appSupport.appendingPathComponent("conversations", isDirectory: true)
        )
        self.conversationStore = conversationStore

        let memoryStore = MemoryStore(
            directory: appSupport.appendingPathComponent("memory", isDirectory: true)
        )
        self.memoryStore = memoryStore

        let secureKeyStore = SecureKeyStore()
        self.secureKeyStore = secureKeyStore

        let skillSettingsStore = SkillSettingsStore(
            directory: appSupport.appendingPathComponent("settings", isDirectory: true)
        )
        self.skillSettingsStore = skillSettingsStore

        let providerSettings = AIProviderSettings(
            directory: appSupport.appendingPathComponent("settings", isDirectory: true)
        )
        self.providerSettings = providerSettings

        let providerRegistry = AIProviderRegistry()
        providerRegistry.register(.openAI)
        providerRegistry.register(.anthropic)
        providerRegistry.register(.google)
        providerRegistry.register(.nvidia)
        providerRegistry.register(.local)
        self.providerRegistry = providerRegistry

        let skillRegistry = SkillRegistry()
        self.skillRegistry = skillRegistry

        let httpClient = HTTPClient()
        let agentCore = AgentCore(
            providerRegistry: providerRegistry,
            providerSettings: providerSettings,
            secureKeyStore: secureKeyStore,
            skillRegistry: skillRegistry,
            skillSettingsStore: skillSettingsStore,
            memoryStore: memoryStore,
            conversationStore: conversationStore,
            httpClient: httpClient,
            logger: logger
        )
        self.agentCore = agentCore

        // Register built-in skills
        registerSkills(httpClient: httpClient)

        // Load persisted data
        Task {
            await loadConversations()
        }
    }

    private func registerSkills(httpClient: HTTPClient) {
        skillRegistry.register(WebSearchSkill(httpClient: httpClient, keyStore: secureKeyStore))
        skillRegistry.register(NewsSkill(httpClient: httpClient, keyStore: secureKeyStore))
        skillRegistry.register(WebBrowserSkill(httpClient: httpClient))
        skillRegistry.register(VoiceInputSkill())
        skillRegistry.register(VoiceOutputSkill())
        skillRegistry.register(VisionSkill())
        skillRegistry.register(FilesSkill())
        skillRegistry.register(MemorySkill(memoryStore: memoryStore))
        skillRegistry.register(CalendarSkill())
        skillRegistry.register(RemindersSkill())
        skillRegistry.register(WeatherSkill(httpClient: httpClient))
        skillRegistry.register(APISkill(httpClient: httpClient, keyStore: secureKeyStore))
        skillRegistry.register(CodeSkill(httpClient: httpClient))
    }

    func loadConversations() async {
        do {
            conversations = try conversationStore.fetchAllConversations()
            if conversations.isEmpty {
                currentConversation = try conversationStore.createConversation(title: "Nouvelle conversation")
                conversations = try conversationStore.fetchAllConversations()
            } else {
                currentConversation = conversations.first
            }
        } catch {
            logger.error("Failed to load conversations: \(error)")
        }
    }

    func startNewConversation() async {
        do {
            currentConversation = try conversationStore.createConversation(title: "Nouvelle conversation")
            conversations = try conversationStore.fetchAllConversations()
            selectedTab = .chat
        } catch {
            logger.error("Failed to create conversation: \(error)")
        }
    }
}

enum AppTab: Hashable {
    case chat, voice, skills, memory, history, settings
}

enum AppTheme: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "Système"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }
}
