import Foundation

/// The result returned by a skill after execution.
struct SkillResult: Sendable {
    let output: JSONValue
    let summary: String?
    let sources: [Source]
    let data: Data?

    init(output: JSONValue, summary: String? = nil, sources: [Source] = [], data: Data? = nil) {
        self.output = output
        self.summary = summary
        self.sources = sources
        self.data = data
    }
}

/// Permissions that a skill might request.
enum SkillPermission: String, Codable, CaseIterable, Sendable {
    case microphone
    case speechRecognition
    case camera
    case photoLibrary
    case location
    case calendar
    case reminders
    case fileAccess
    case network
    case contacts

    var description: String {
        switch self {
        case .microphone: return "Accès au microphone"
        case .speechRecognition: return "Reconnaissance vocale"
        case .camera: return "Accès à la caméra"
        case .photoLibrary: return "Accès à la photothèque"
        case .location: return "Accès à la localisation"
        case .calendar: return "Accès au calendrier"
        case .reminders: return "Accès aux rappels"
        case .fileAccess: return "Accès aux fichiers"
        case .network: return "Accès réseau"
        case .contacts: return "Accès aux contacts"
        }
    }

    var usageDescriptionKey: String {
        switch self {
        case .microphone: return "NSMicrophoneUsageDescription"
        case .speechRecognition: return "NSSpeechRecognitionUsageDescription"
        case .camera: return "NSCameraUsageDescription"
        case .photoLibrary: return "NSPhotoLibraryUsageDescription"
        case .location: return "NSLocationWhenInUseUsageDescription"
        case .calendar: return "NSCalendarsUsageDescription"
        case .reminders: return "NSRemindersUsageDescription"
        case .fileAccess: return "NSDocumentsFolderUsageDescription"
        case .network: return "" // No Info.plist key needed for network
        case .contacts: return "NSContactsUsageDescription"
        }
    }
}

/// Errors that can occur during skill execution.
enum SkillError: LocalizedError {
    case missingAPIKey(provider: String)
    case permissionDenied(SkillPermission)
    case invalidInput(String)
    case networkError(String)
    case unsupportedOnDevice(String)
    case cancelled
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Clé API manquante pour \(provider). Configurez-la dans les paramètres."
        case .permissionDenied(let perm):
            return "Permission refusée: \(perm.description)"
        case .invalidInput(let detail):
            return "Entrée invalide: \(detail)"
        case .networkError(let detail):
            return "Erreur réseau: \(detail)"
        case .unsupportedOnDevice(let detail):
            return "Non supporté sur cet appareil: \(detail)"
        case .cancelled:
            return "Opération annulée"
        case .custom(let detail):
            return detail
        }
    }
}

/// The protocol that all skills must conform to.
/// Each skill is a self-contained module with its own input schema,
/// output schema, permissions, and execution logic.
protocol AgentSkill: AnyObject, Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var category: SkillCategory { get }
    var requiredPermissions: [SkillPermission] { get }
    var inputSchema: JSONValue { get }
    var outputSchema: JSONValue { get }
    var requiresConfirmation: Bool { get }

    /// Execute the skill with the given input.
    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult

    /// Check if this skill requires confirmation for a specific input.
    func requiresConfirmation(for input: JSONValue) -> Bool

    /// The description to show when requesting confirmation.
    func confirmationDescription(for input: JSONValue) -> String
}

extension AgentSkill {
    var category: SkillCategory { .general }
    var requiresConfirmation: Bool { false }

    func requiresConfirmation(for input: JSONValue) -> Bool {
        self.requiresConfirmation
    }

    func confirmationDescription(for input: JSONValue) -> String {
        "Exécuter \(self.name)?"
    }

    /// Convert this skill to a tool definition for the AI provider.
    func toToolDefinition() -> ToolDefinition {
        ToolDefinition(
            name: id,
            description: description,
            parameters: inputSchema
        )
    }
}

enum SkillCategory: String, CaseIterable, Codable, Sendable {
    case general, search, news, browser, voice, vision, files, memory, calendar, reminders, weather, api, code

    var displayName: String {
        switch self {
        case .general: return "Général"
        case .search: return "Recherche"
        case .news: return "Actualités"
        case .browser: return "Navigateur"
        case .voice: return "Voix"
        case .vision: return "Vision"
        case .files: return "Fichiers"
        case .memory: return "Mémoire"
        case .calendar: return "Calendrier"
        case .reminders: return "Rappels"
        case .weather: return "Météo"
        case .api: return "API"
        case .code: return "Code"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "sparkles"
        case .search: return "magnifyingglass"
        case .news: return "newspaper"
        case .browser: return "safari"
        case .voice: return "mic"
        case .vision: return "eye"
        case .files: return "folder"
        case .memory: return "brain.head.profile"
        case .calendar: return "calendar"
        case .reminders: return "bell"
        case .weather: return "cloud.sun"
        case .api: return "network"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
