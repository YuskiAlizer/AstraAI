import XCTest
@testable import AstraAI

@MainActor
final class MemoryStoreTests: XCTestCase {

    func testAddMemory() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_mem_\(UUID().uuidString)")
        let store = MemoryStore(directory: dir)

        store.add(category: "preferences", key: "color", value: "blue")

        XCTAssertEqual(store.memories.count, 1)
        XCTAssertEqual(store.memories.first?.category, "preferences")
        XCTAssertEqual(store.memories.first?.key, "color")
        XCTAssertEqual(store.memories.first?.value, "blue")
    }

    func testUpdateMemory() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_mem_update_\(UUID().uuidString)")
        let store = MemoryStore(directory: dir)

        store.add(category: "preferences", key: "color", value: "blue")
        store.add(category: "preferences", key: "color", value: "red")

        XCTAssertEqual(store.memories.count, 1)
        XCTAssertEqual(store.memories.first?.value, "red")
    }

    func testDeleteMemory() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_mem_delete_\(UUID().uuidString)")
        let store = MemoryStore(directory: dir)

        store.add(category: "preferences", key: "color", value: "blue")
        let memoryId = store.memories.first!.id

        store.delete(id: memoryId)

        XCTAssertEqual(store.memories.count, 0)
    }

    func testSearchMemory() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_mem_search_\(UUID().uuidString)")
        let store = MemoryStore(directory: dir)

        store.add(category: "preferences", key: "color", value: "blue")
        store.add(category: "facts", key: "city", value: "Paris")
        store.add(category: "preferences", key: "food", value: "pizza")

        let results = store.search(query: "blue")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.key, "color")

        let prefResults = store.search(query: "preferences")
        XCTAssertEqual(prefResults.count, 2)
    }

    func testCategories() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_mem_cat_\(UUID().uuidString)")
        let store = MemoryStore(directory: dir)

        store.add(category: "preferences", key: "color", value: "blue")
        store.add(category: "facts", key: "city", value: "Paris")

        let categories = store.categories()
        XCTAssertEqual(categories.count, 2)
        XCTAssertTrue(categories.contains("preferences"))
        XCTAssertTrue(categories.contains("facts"))
    }

    func testDeleteAllMemories() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_mem_all_\(UUID().uuidString)")
        let store = MemoryStore(directory: dir)

        store.add(category: "a", key: "1", value: "x")
        store.add(category: "b", key: "2", value: "y")

        store.deleteAll()

        XCTAssertEqual(store.memories.count, 0)
    }

    func testMemoryPersistence() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_mem_persist_\(UUID().uuidString)")

        // Add memory
        let store1 = MemoryStore(directory: dir)
        store1.add(category: "preferences", key: "color", value: "green")

        // Create new store from same directory
        let store2 = MemoryStore(directory: dir)
        XCTAssertEqual(store2.memories.count, 1)
        XCTAssertEqual(store2.memories.first?.value, "green")
    }
}
