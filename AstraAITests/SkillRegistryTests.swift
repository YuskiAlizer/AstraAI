import XCTest
@testable import AstraAI

@MainActor
final class SkillRegistryTests: XCTestCase {

    func testSkillRegistration() {
        let registry = SkillRegistry()
        let skill = MockSkill()
        registry.register(skill)

        XCTAssertEqual(registry.skillCount, 1)
        XCTAssertEqual(registry.skill(id: "mock")?.name, "Mock Skill")
    }

    func testSkillDiscovery() {
        let registry = SkillRegistry()
        let skill1 = MockSkill(id: "skill1", name: "Skill 1")
        let skill2 = MockSkill(id: "skill2", name: "Skill 2")
        registry.register(skill1)
        registry.register(skill2)

        XCTAssertEqual(registry.allSkills.count, 2)
        XCTAssertNotNil(registry.skill(id: "skill1"))
        XCTAssertNotNil(registry.skill(id: "skill2"))
    }

    func testSkillSettingsEnableDisable() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_skills_\(UUID().uuidString)")
        let store = SkillSettingsStore(directory: dir)

        // Skills are enabled by default
        XCTAssertTrue(store.isEnabled(skillId: "test_skill"))

        // Disable
        store.setEnabled(false, for: "test_skill")
        XCTAssertFalse(store.isEnabled(skillId: "test_skill"))

        // Re-enable
        store.setEnabled(true, for: "test_skill")
        XCTAssertTrue(store.isEnabled(skillId: "test_skill"))
    }

    func testSkillSettingsToggle() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("test_skills_toggle_\(UUID().uuidString)")
        let store = SkillSettingsStore(directory: dir)

        let initial = store.isEnabled(skillId: "toggle_test")
        store.toggle(skillId: "toggle_test")
        XCTAssertNotEqual(store.isEnabled(skillId: "toggle_test"), initial)
    }

    func testToolDefinitionGeneration() {
        let skill = MockSkill()
        let def = skill.toToolDefinition()

        XCTAssertEqual(def.name, "mock")
        XCTAssertFalse(def.description.isEmpty)
    }
}

// MARK: - Mock Skill

final class MockSkill: AgentSkill, @unchecked Sendable {
    let id: String
    let name: String
    let description = "A mock skill for testing"
    let category: SkillCategory = .general
    let requiredPermissions: [SkillPermission] = []
    let requiresConfirmation = false

    var inputSchema: JSONValue {
        .object(["type": .string("object"), "properties": .object([:])])
    }

    var outputSchema: JSONValue {
        .object(["type": .string("object"), "properties": .object([:])])
    }

    init(id: String = "mock", name: String = "Mock Skill") {
        self.id = id
        self.name = name
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        SkillResult(output: .object(["result": .string("mock")]), summary: "Mock executed")
    }
}
