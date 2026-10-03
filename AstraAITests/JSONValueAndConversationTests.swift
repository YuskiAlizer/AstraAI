import XCTest
@testable import AstraAI

@MainActor
final class JSONValueTests: XCTestCase {

    func testStringConversion() {
        let value = JSONValue.string("hello")
        XCTAssertEqual(value.stringValue, "hello")
    }

    func testNumberConversion() {
        let value = JSONValue.number(42.5)
        XCTAssertEqual(value.doubleValue, 42.5)
        XCTAssertEqual(value.intValue, 42)
    }

    func testBoolConversion() {
        let value = JSONValue.bool(true)
        XCTAssertEqual(value.boolValue, true)
    }

    func testObjectAccess() {
        let value: JSONValue = .object([
            "name": .string("Astra"),
            "version": .number(1.0)
        ])

        XCTAssertEqual(value["name"]?.stringValue, "Astra")
        XCTAssertEqual(value["version"]?.doubleValue, 1.0)
    }

    func testArrayAccess() {
        let value: JSONValue = .array([.string("a"), .string("b"), .string("c")])
        XCTAssertEqual(value[0]?.stringValue, "a")
        XCTAssertEqual(value[1]?.stringValue, "b")
        XCTAssertEqual(value[2]?.stringValue, "c")
    }

    func testJSONStringRoundTrip() {
        let original: JSONValue = .object([
            "name": .string("test"),
            "value": .number(42),
            "items": .array([.string("a"), .string("b")])
        ])

        let jsonString = original.jsonString()
        let parsed = JSONValue.from(jsonString: jsonString)

        XCTAssertEqual(parsed?["name"]?.stringValue, "test")
        XCTAssertEqual(parsed?["value"]?.intValue, 42)
        XCTAssertEqual(parsed?["items"]?.arrayValue?.count, 2)
    }

    func testNullValue() {
        let value = JSONValue.null
        XCTAssertNil(value.stringValue)
        XCTAssertNil(value.intValue)
    }
}

@MainActor
final class ConversationStoreTests: XCTestCase {

    func testCreateConversation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_conv_\(UUID().uuidString)")
        let store = ConversationStore(directory: dir)

        let conversation = try store.createConversation(title: "Test")

        XCTAssertEqual(conversation.title, "Test")
        XCTAssertEqual(conversation.messages.count, 0)
    }

    func testSaveAndFetchConversation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_conv_save_\(UUID().uuidString)")
        let store = ConversationStore(directory: dir)

        var conversation = try store.createConversation(title: "Test")
        conversation.messages.append(.user("Hello"))
        try store.saveConversation(conversation)

        let fetched = try store.fetchConversation(id: conversation.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Test")
        XCTAssertEqual(fetched?.messages.count, 1)
    }

    func testFetchAllConversations() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_conv_all_\(UUID().uuidString)")
        let store = ConversationStore(directory: dir)

        _ = try store.createConversation(title: "Conv 1")
        _ = try store.createConversation(title: "Conv 2")

        let all = try store.fetchAllConversations()
        XCTAssertEqual(all.count, 2)
    }

    func testDeleteConversation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_conv_del_\(UUID().uuidString)")
        let store = ConversationStore(directory: dir)

        let conversation = try store.createConversation(title: "Test")
        try store.deleteConversation(id: conversation.id)

        let fetched = try store.fetchConversation(id: conversation.id)
        XCTAssertNil(fetched)
    }
}

// MARK: - Test Environment Helper

enum TestEnvironment {
    @MainActor
    static func create() -> AppEnvironment {
        AppEnvironment()
    }
}
