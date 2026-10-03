import Foundation

/// Code Skill — allows the agent to write and analyze code.
/// Does NOT execute arbitrary code on the iPhone for security reasons.
/// Code analysis (syntax checking, explanation) is done via the AI provider.
/// A sandboxed backend can be configured for execution if needed.
final class CodeSkill: AgentSkill, @unchecked Sendable {

    let id = "code"
    let name = "Code"
    let description = "Écrit, analyse et explique du code. N'exécute PAS de code arbitraire sur l'iPhone pour des raisons de sécurité. Un backend sandboxé peut être configuré pour l'exécution."
    let category: SkillCategory = .code
    let requiredPermissions: [SkillPermission] = [.network]

    private let httpClient: HTTPClient
    private let backendURLKey = "code_backend_url"

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action: 'generate' (générer du code), 'analyze' (analyser du code), 'explain' (expliquer du code), 'execute' (exécuter via backend sandboxé)"),
                    "enum": .array([.string("generate"), .string("analyze"), .string("explain"), .string("execute")])
                ]),
                "language": .object([
                    "type": .string("string"),
                    "description": .string("Langage de programmation (ex: Python, JavaScript, Swift)")
                ]),
                "code": .object([
                    "type": .string("string"),
                    "description": .string("Le code à analyser/expliquer/exécuter")
                ]),
                "description": .object([
                    "type": .string("string"),
                    "description": .string("Description de ce que le code doit faire (pour generate)")
                ])
            ]),
            "required": .array([.string("action")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "code": .string("Le code généré ou analysé"),
                "explanation": .string("Explication du code"),
                "result": .string("Résultat de l'exécution (si applicable)")
            ])
        ])
    }

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let action = input["action"]?.stringValue else {
            throw SkillError.invalidInput("Le paramètre 'action' est requis")
        }

        switch action {
        case "generate":
            return try await generateCode(input: input, context: context)
        case "analyze":
            return try await analyzeCode(input: input, context: context)
        case "explain":
            return try await explainCode(input: input, context: context)
        case "execute":
            return try await executeCode(input: input, context: context)
        default:
            throw SkillError.invalidInput("Action inconnue: \(action)")
        }
    }

    func requiresConfirmation(for input: JSONValue) -> Bool {
        guard let action = input["action"]?.stringValue else { return false }
        return action == "execute"
    }

    func confirmationDescription(for input: JSONValue) -> String {
        let language = input["language"]?.stringValue ?? "code"
        return "Exécuter du code \(language) via le backend sandboxé?"
    }

    // MARK: - Generate

    private func generateCode(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let description = input["description"]?.stringValue else {
            throw SkillError.invalidInput("Le paramètre 'description' est requis pour 'generate'")
        }

        let language = input["language"]?.stringValue ?? "Python"

        context.emitEvent(.statusChanged("Génération de code \(language)..."))

        // This skill returns a prompt for the AI model to generate code.
        // The actual generation happens through the agent loop's AI provider call.
        let output: JSONValue = .object([
            "action": .string("generate"),
            "language": .string(language),
            "description": .string(description),
            "instruction": .string("Génère du code en \(language) pour: \(description). Réponds avec le code uniquement, sans markdown."),
            "note": .string("Le code sera généré par le modèle IA. Il ne sera pas exécuté sur l'appareil.")
        ])

        return SkillResult(
            output: output,
            summary: "Demande de génération de code \(language) préparée"
        )
    }

    // MARK: - Analyze

    private func analyzeCode(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let code = input["code"]?.stringValue, !code.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'code' est requis pour 'analyze'")
        }

        let language = input["language"]?.stringValue ?? "inconnu"

        context.emitEvent(.statusChanged("Analyse du code \(language)..."))

        // Return the code for the AI model to analyze
        let output: JSONValue = .object([
            "action": .string("analyze"),
            "language": .string(language),
            "code": .string(code),
            "instruction": .string("Analyse ce code \(language). Identifie les problèmes potentiels, les bugs, les améliorations possibles. Sois précis et concis."),
            "note": .string("L'analyse sera effectuée par le modèle IA. Aucune exécution locale.")
        ])

        return SkillResult(
            output: output,
            summary: "Code \(language) prêt pour analyse"
        )
    }

    // MARK: - Explain

    private func explainCode(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let code = input["code"]?.stringValue, !code.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'code' est requis pour 'explain'")
        }

        let language = input["language"]?.stringValue ?? "inconnu"

        context.emitEvent(.statusChanged("Explication du code \(language)..."))

        let output: JSONValue = .object([
            "action": .string("explain"),
            "language": .string(language),
            "code": .string(code),
            "instruction": .string("Explique ce code \(language) de manière claire et pédagogique. Décris ce qu'il fait, comment il fonctionne, et les concepts importants."),
            "note": .string("L'explication sera générée par le modèle IA.")
        ])

        return SkillResult(
            output: output,
            summary: "Code \(language) prêt pour explication"
        )
    }

    // MARK: - Execute (via sandboxed backend)

    private func executeCode(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let code = input["code"]?.stringValue, !code.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'code' est requis pour 'execute'")
        }

        let language = input["language"]?.stringValue ?? "python"

        // Check if a backend URL is configured
        guard let backendURL = await SecureKeyStore().loadCustomAPIKey(identifier: backendURLKey),
              !backendURL.isEmpty,
              let url = URL(string: backendURL) else {
            throw SkillError.unsupportedOnDevice("""
            L'exécution de code nécessite un backend sandboxé configuré.
            Configurez l'URL du backend dans Paramètres > API avec l'identifiant 'code_backend_url'.
            Le backend doit accepter les requêtes POST avec du code et retourner le résultat.
            L'exécution de code arbitraire sur l'iPhone n'est pas autorisée pour des raisons de sécurité.
            """)
        }

        context.emitEvent(.statusChanged("Exécution du code via le backend..."))

        // Send code to sandboxed backend
        let body: [String: Any] = [
            "language": language,
            "code": code
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let response = try await httpClient.post(
            url.absoluteString,
            body: bodyData,
            headers: ["Content-Type": "application/json"]
        )

        let result: JSONValue
        if let data = response.body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) {
            result = anyToJSONValue(json)
        } else {
            result = .string(response.body)
        }

        let output: JSONValue = .object([
            "action": .string("execute"),
            "language": .string(language),
            "result": result,
            "statusCode": .number(Double(response.statusCode))
        ])

        return SkillResult(
            output: output,
            summary: "Code \(language) exécuté via backend (HTTP \(response.statusCode))"
        )
    }

    // MARK: - Helpers

    private func anyToJSONValue(_ value: Any) -> JSONValue {
        if let v = value as? NSNull { return .null }
        if let v = value as? Bool { return .bool(v) }
        if let v = value as? Int { return .number(Double(v)) }
        if let v = value as? Double { return .number(v) }
        if let v = value as? String { return .string(v) }
        if let v = value as? [Any] { return .array(v.map { anyToJSONValue($0) }) }
        if let v = value as? [String: Any] {
            var dict: [String: JSONValue] = [:]
            for (k, val) in v { dict[k] = anyToJSONValue(val) }
            return .object(dict)
        }
        return .null
    }
}
