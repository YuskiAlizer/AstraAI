import Foundation

/// A user memory entry — a structured, persistent fact.
struct UserMemory: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var category: String
    var key: String
    var value: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), category: String, key: String, value: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.category = category
        self.key = key
        self.value = value
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Manages persistent user memories. Each memory is a key-value pair
/// categorized for easy retrieval. Stored as a single JSON file.
@MainActor
final class MemoryStore: ObservableObject {

    @Published private(set) var memories: [UserMemory] = []

    private let fileURL: URL
    private let logger = AppLogger.shared

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("memories.json")
        load()
    }

    // MARK: - CRUD

    func add(category: String, key: String, value: String) {
        // Update if exists
        if let index = memories.firstIndex(where: { $0.category == category && $0.key == key }) {
            memories[index].value = value
            memories[index].updatedAt = Date()
        } else {
            memories.append(UserMemory(category: category, key: key, value: value))
        }
        save()
    }

    func update(id: UUID, value: String) {
        if let index = memories.firstIndex(where: { $0.id == id }) {
            memories[index].value = value
            memories[index].updatedAt = Date()
            save()
        }
    }

    func delete(id: UUID) {
        memories.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        memories.removeAll()
        save()
    }

    func search(query: String) -> [UserMemory] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return memories.filter {
            $0.category.lowercased().contains(lowered) ||
            $0.key.lowercased().contains(lowered) ||
            $0.value.lowercased().contains(lowered)
        }
    }

    func categories() -> [String] {
        Array(Set(memories.map { $0.category })).sorted()
    }

    func memories(in category: String) -> [UserMemory] {
        memories.filter { $0.category == category }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let stored = try? decoder.decode([UserMemory].self, from: data) {
            self.memories = stored
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(memories) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
