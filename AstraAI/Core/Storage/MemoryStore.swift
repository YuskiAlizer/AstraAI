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
final class MemoryStore: ObservableObject {

    @Published private(set) var memories: [UserMemory] = []

    private let fileURL: URL
    private let logger = AppLogger.shared
    private let queue = DispatchQueue(label: "com.astraai.memorystore", attributes: .concurrent)

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("memories.json")
        load()
    }

    // MARK: - CRUD (nonisolated — safe from any actor)

    nonisolated func add(category: String, key: String, value: String) {
        queue.sync(flags: .barrier) {
            if let index = self.memories.firstIndex(where: { $0.category == category && $0.key == key }) {
                self.memories[index].value = value
                self.memories[index].updatedAt = Date()
            } else {
                self.memories.append(UserMemory(category: category, key: key, value: value))
            }
            self.save()
        }
    }

    nonisolated func update(id: UUID, value: String) {
        queue.sync(flags: .barrier) {
            if let index = self.memories.firstIndex(where: { $0.id == id }) {
                self.memories[index].value = value
                self.memories[index].updatedAt = Date()
                self.save()
            }
        }
    }

    nonisolated func delete(id: UUID) {
        queue.sync(flags: .barrier) {
            self.memories.removeAll { $0.id == id }
            self.save()
        }
    }

    nonisolated func deleteAll() {
        queue.sync(flags: .barrier) {
            self.memories.removeAll()
            self.save()
        }
    }

    nonisolated func search(query: String) -> [UserMemory] {
        queue.sync {
            guard !query.isEmpty else { return [] }
            let lowered = query.lowercased()
            return self.memories.filter {
                $0.category.lowercased().contains(lowered) ||
                $0.key.lowercased().contains(lowered) ||
                $0.value.lowercased().contains(lowered)
            }
        }
    }

    nonisolated func categories() -> [String] {
        queue.sync {
            Array(Set(self.memories.map { $0.category })).sorted()
        }
    }

    nonisolated func memories(in category: String) -> [UserMemory] {
        queue.sync {
            self.memories.filter { $0.category == category }
        }
    }

    // MARK: - Persistence

    nonisolated private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let stored = try? decoder.decode([UserMemory].self, from: data) {
            self.memories = stored
        }
    }

    nonisolated private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(memories) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
