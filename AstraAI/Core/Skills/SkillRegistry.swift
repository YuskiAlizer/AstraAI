import Foundation
import SwiftUI

/// Registry that discovers, stores, and manages all available skills.
@MainActor
final class SkillRegistry: ObservableObject {

    @Published private(set) var skills: [String: AgentSkill] = [:]

    func register(_ skill: AgentSkill) {
        skills[skill.id] = skill
    }

    func skill(id: String) -> AgentSkill? {
        skills[id]
    }

    var allSkills: [AgentSkill] {
        Array(skills.values).sorted { $0.id < $1.id }
    }

    var skillCount: Int { skills.count }
}

/// Stores enabled/disabled state for each skill. Persisted to disk.
@MainActor
final class SkillSettingsStore: ObservableObject {

    @Published private(set) var enabledSkills: Set<String>
    @Published private(set) var disabledSkills: Set<String>

    private let fileURL: URL

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("skill_settings.json")
        self.enabledSkills = []
        self.disabledSkills = []
        load()
    }

    func isEnabled(skillId: String) -> Bool {
        if disabledSkills.contains(skillId) { return false }
        return true // Enabled by default
    }

    func setEnabled(_ enabled: Bool, for skillId: String) {
        if enabled {
            disabledSkills.remove(skillId)
            enabledSkills.insert(skillId)
        } else {
            enabledSkills.remove(skillId)
            disabledSkills.insert(skillId)
        }
        save()
    }

    func toggle(skillId: String) {
        setEnabled(!isEnabled(skillId: skillId), for: skillId)
    }

    // MARK: - Persistence

    private struct PersistedData: Codable {
        var disabledSkills: [String]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let stored = try? decoder.decode(PersistedData.self, from: data) {
            self.disabledSkills = Set(stored.disabledSkills)
        }
    }

    private func save() {
        let data = PersistedData(disabledSkills: Array(disabledSkills))
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }
}
