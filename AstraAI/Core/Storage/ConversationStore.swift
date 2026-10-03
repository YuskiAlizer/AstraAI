import Foundation

/// A conversation with its messages and metadata.
struct Conversation: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var messages: [AgentMessage]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, messages: [AgentMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var lastUserMessage: String? {
        messages.last(where: { $0.role == .user })?.content
    }

    var preview: String {
        messages.last?.content ?? "Aucun message"
    }
}

/// Manages conversation persistence in the app's Application Support directory.
/// Each conversation is stored as a separate JSON file.
@MainActor
final class ConversationStore {

    private let directory: URL
    private let logger = AppLogger.shared
    private let fileManager = FileManager.default

    init(directory: URL) {
        self.directory = directory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - CRUD

    func createConversation(title: String = "Nouvelle conversation") throws -> Conversation {
        let conversation = Conversation(title: title)
        try saveConversation(conversation)
        return conversation
    }

    func saveConversation(_ conversation: Conversation) throws {
        let fileURL = directory.appendingPathComponent("\(conversation.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conversation)
        try data.write(to: fileURL, options: .atomic)
    }

    func deleteConversation(id: UUID) throws {
        let fileURL = directory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
    }

    func fetchConversation(id: UUID) throws -> Conversation? {
        let fileURL = directory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Conversation.self, from: data)
    }

    func fetchAllConversations() throws -> [Conversation] {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
        var conversations: [Conversation] = []

        for url in urls where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let conversation = try? decoder.decode(Conversation.self, from: data) {
                    conversations.append(conversation)
                }
            } catch {
                logger.warning("Failed to decode conversation at \(url.path): \(error)")
            }
        }

        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func deleteAllConversations() throws {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls where url.pathExtension == "json" {
            try? fileManager.removeItem(at: url)
        }
    }
}
