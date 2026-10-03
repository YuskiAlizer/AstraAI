import Foundation

/// Memory Skill — allows the agent to store, retrieve, update, and delete
/// persistent memories about the user. Never stores sensitive information
/// without confirmation.
final class MemorySkill: AgentSkill, @unchecked Sendable {

    let id = "memory"
    let name = "Mémoire"
    let description = "Stocke, récupère, modifie et supprime des souvenirs persistants. Permet à l'agent de se souvenir d'informations entre les conversations."
    let category: SkillCategory = .memory
    let requiredPermissions: [SkillPermission] = []
    let requiresConfirmation = true

    private let memoryStore: MemoryStore

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action: 'add' (ajouter), 'search' (rechercher), 'update' (modifier), 'delete' (supprimer), 'list' (lister)"),
                    "enum": .array([.string("add"), .string("search"), .string("update"), .string("delete"), .string("list")])
                ]),
                "category": .object([
                    "type": .string("string"),
                    "description": .string("Catégorie du souvenir (ex: préférences, faits, projets)")
                ]),
                "key": .object([
                    "type": .string("string"),
                    "description": .string("Clé du souvenir")
                ]),
                "value": .object([
                    "type": .string("string"),
                    "description": .string("Valeur du souvenir")
                ]),
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Requête de recherche (pour search)")
                ])
            ]),
            "required": .array([.string("action")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "success": .bool(true),
                "memories": .array([.object([:])]),
                "message": .string("Description du résultat")
            ])
        ])
    }

    init(memoryStore: MemoryStore) {
        self.memoryStore = memoryStore
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let action = input["action"]?.stringValue else {
            throw SkillError.invalidInput("Le paramètre 'action' est requis")
        }

        switch action {
        case "add":
            return try await addMemory(input: input, context: context)
        case "search":
            return try await searchMemory(input: input, context: context)
        case "update":
            return try await updateMemory(input: input, context: context)
        case "delete":
            return try await deleteMemory(input: input, context: context)
        case "list":
            return try await listMemories(context: context)
        default:
            throw SkillError.invalidInput("Action inconnue: \(action)")
        }
    }

    func requiresConfirmation(for input: JSONValue) -> Bool {
        guard let action = input["action"]?.stringValue else { return false }
        // Require confirmation for add/update/delete of potentially sensitive info
        if action == "add" || action == "update" {
            // Don't require confirmation for simple preferences
            if let category = input["category"]?.stringValue,
               category == "preferences" {
                return false
            }
            return true
        }
        if action == "delete" { return true }
        return false
    }

    func confirmationDescription(for input: JSONValue) -> String {
        guard let action = input["action"]?.stringValue else { return "Opération sur la mémoire?" }
        let key = input["key"]?.stringValue ?? ""
        let value = input["value"]?.stringValue ?? ""
        switch action {
        case "add": return "Mémoriser: \(key) = \(value)?"
        case "update": return "Modifier le souvenir « \(key) »?"
        case "delete": return "Supprimer le souvenir « \(key) »?"
        default: return "Opération sur la mémoire?"
        }
    }

    // MARK: - Actions

    private func addMemory(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let category = input["category"]?.stringValue,
              let key = input["key"]?.stringValue,
              let value = input["value"]?.stringValue else {
            throw SkillError.invalidInput("Les paramètres 'category', 'key' et 'value' sont requis")
        }

        context.emitEvent(.statusChanged("Mémorisation de \(key)..."))

        memoryStore.add(category: category, key: key, value: value)

        let output: JSONValue = .object([
            "success": .bool(true),
            "message": .string("Souvenir enregistré: \(category)/\(key)")
        ])

        return SkillResult(
            output: output,
            summary: "Souvenir enregistré: \(category)/\(key)"
        )
    }

    private func searchMemory(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        let query = input["query"]?.stringValue ?? ""

        context.emitEvent(.statusChanged("Recherche dans la mémoire..."))

        let results = memoryStore.search(query: query)

        let memoriesArray: [JSONValue] = results.map { mem in
            .object([
                "id": .string(mem.id.uuidString),
                "category": .string(mem.category),
                "key": .string(mem.key),
                "value": .string(mem.value),
                "createdAt": .string(ISO8601DateFormatter().string(from: mem.createdAt)),
                "updatedAt": .string(ISO8601DateFormatter().string(from: mem.updatedAt))
            ])
        }

        let output: JSONValue = .object([
            "memories": .array(memoriesArray),
            "total": .number(Double(results.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(results.count) souvenir(s) trouvé(s)"
        )
    }

    private func updateMemory(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let id = input["id"]?.stringValue,
              let value = input["value"]?.stringValue else {
            throw SkillError.invalidInput("Les paramètres 'id' et 'value' sont requis")
        }

        guard let uuid = UUID(uuidString: id) else {
            throw SkillError.invalidInput("ID invalide")
        }

        memoryStore.update(id: uuid, value: value)

        let output: JSONValue = .object([
            "success": .bool(true),
            "message": .string("Souvenir mis à jour")
        ])

        return SkillResult(
            output: output,
            summary: "Souvenir mis à jour"
        )
    }

    private func deleteMemory(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let id = input["id"]?.stringValue else {
            throw SkillError.invalidInput("Le paramètre 'id' est requis")
        }

        guard let uuid = UUID(uuidString: id) else {
            throw SkillError.invalidInput("ID invalide")
        }

        memoryStore.delete(id: uuid)

        let output: JSONValue = .object([
            "success": .bool(true),
            "message": .string("Souvenir supprimé")
        ])

        return SkillResult(
            output: output,
            summary: "Souvenir supprimé"
        )
    }

    private func listMemories(context: SkillExecutionContext) async throws -> SkillResult {
        let categories = memoryStore.categories()

        let categoriesArray: [JSONValue] = categories.map { cat in
            let mems = memoryStore.memories(in: cat)
            let memArray: [JSONValue] = mems.map { m in
                .object([
                    "id": .string(m.id.uuidString),
                    "key": .string(m.key),
                    "value": .string(m.value),
                    "updatedAt": .string(ISO8601DateFormatter().string(from: m.updatedAt))
                ])
            }
            return .object([
                "category": .string(cat),
                "memories": .array(memArray),
                "count": .number(Double(mems.count))
            ])
        }

        let output: JSONValue = .object([
            "categories": .array(categoriesArray),
            "total": .number(Double(memoryStore.memories.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(categories.count) catégorie(s), \(memoryStore.memories.count) souvenir(s)"
        )
    }
}
