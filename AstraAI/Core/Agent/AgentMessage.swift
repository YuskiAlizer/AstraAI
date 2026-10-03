import Foundation

/// A message in a conversation, with role and content.
struct AgentMessage: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var role: MessageRole
    var content: String
    var toolCalls: [ToolCall]
    var toolCallId: String?
    var toolName: String?
    var sources: [Source]
    var attachments: [Attachment]
    var createdAt: Date
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String = "",
        toolCalls: [ToolCall] = [],
        toolCallId: String? = nil,
        toolName: String? = nil,
        sources: [Source] = [],
        attachments: [Attachment] = [],
        createdAt: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.sources = sources
        self.attachments = attachments
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }

    static func user(_ text: String, attachments: [Attachment] = []) -> AgentMessage {
        AgentMessage(role: .user, content: text, attachments: attachments)
    }

    static func assistant(_ text: String, sources: [Source] = []) -> AgentMessage {
        AgentMessage(role: .assistant, content: text, sources: sources)
    }

    static func tool(name: String, result: String, toolCallId: String) -> AgentMessage {
        AgentMessage(role: .tool, content: result, toolCallId: toolCallId, toolName: name)
    }

    static func system(_ text: String) -> AgentMessage {
        AgentMessage(role: .system, content: text)
    }
}

enum MessageRole: String, Codable, Sendable {
    case system, user, assistant, tool
}

/// A source reference returned by a skill (e.g., web search result).
struct Source: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var url: String
    var snippet: String
    var date: String?
    var domain: String

    init(id: UUID = UUID(), title: String, url: String, snippet: String, date: String? = nil, domain: String) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.date = date
        self.domain = domain
    }
}

/// An attachment on a user message (image, file, etc.).
struct Attachment: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var type: AttachmentType
    var fileName: String
    var mimeType: String
    var localPath: String
    var fileData: Data?
    var thumbnail: Data?

    init(id: UUID = UUID(), type: AttachmentType, fileName: String, mimeType: String, localPath: String, fileData: Data? = nil, thumbnail: Data? = nil) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.mimeType = mimeType
        self.localPath = localPath
        self.fileData = fileData
        self.thumbnail = thumbnail
    }
}

enum AttachmentType: String, Codable, Sendable {
    case image, pdf, document, other
}
