import Foundation

/// API Skill — a generic system for calling external APIs with secure key storage.
/// Users can configure custom API endpoints with keys stored in Keychain.
/// Never hardcodes secrets in the application.
final class APISkill: AgentSkill, @unchecked Sendable {

    let id = "api"
    let name = "API Externe"
    let description = "Système générique permettant d'appeler des APIs externes configurables. Gestion sécurisée des clés API via Keychain."
    let category: SkillCategory = .api
    let requiredPermissions: [SkillPermission] = [.network]
    let requiresConfirmation = true

    private let httpClient: HTTPClient
    private let keyStore: SecureKeyStore

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("L'URL complète de l'API")
                ]),
                "method": .object([
                    "type": .string("string"),
                    "description": .string("Méthode HTTP: GET, POST, PUT, DELETE"),
                    "enum": .array([.string("GET"), .string("POST"), .string("PUT"), .string("DELETE")]),
                    "default": .string("GET")
                ]),
                "headers": .object([
                    "type": .string("object"),
                    "description": .string("En-têtes HTTP supplémentaires")
                ]),
                "body": .object([
                    "type": .string("string"),
                    "description": .string("Corps de la requête (pour POST/PUT)")
                ]),
                "keyIdentifier": .object([
                    "type": .string("string"),
                    "description": .string("Identifiant de clé API stocké dans Keychain")
                ]),
                "keyHeader": .object([
                    "type": .string("string"),
                    "description": .string("Nom de l'en-tête pour la clé API (ex: Authorization, X-API-Key). Défaut: Authorization"),
                    "default": .string("Authorization")
                ]),
                "keyPrefix": .object([
                    "type": .string("string"),
                    "description": .string("Préfixe pour la clé (ex: 'Bearer '). Vide par défaut."),
                    "default": .string("")
                ])
            ]),
            "required": .array([.string("url")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "statusCode": .number(200),
                "body": .string("Corps de la réponse"),
                "headers": .object([:])
            ])
        ])
    }

    init(httpClient: HTTPClient, keyStore: SecureKeyStore) {
        self.httpClient = httpClient
        self.keyStore = keyStore
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let url = input["url"]?.stringValue, !url.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'url' est requis")
        }

        let method = input["method"]?.stringValue ?? "GET"

        // Require confirmation for non-GET requests
        if method != "GET" {
            let approved = await context.confirm(
                skillName: name,
                action: "api_call",
                description: "Appeler l'API \(method) sur \(url)?",
                arguments: input
            )
            if !approved {
                throw SkillError.cancelled
            }
        }

        context.emitEvent(.statusChanged("Appel API: \(method) \(url)..."))

        // Build headers
        var headers: [String: String] = ["Content-Type": "application/json"]

        // Add custom headers
        if let customHeaders = input["headers"]?.objectValue {
            for (key, value) in customHeaders {
                if let strVal = value.stringValue {
                    headers[key] = strVal
                }
            }
        }

        // Add API key if configured
        if let keyIdentifier = input["keyIdentifier"]?.stringValue {
            if let apiKey = await keyStore.loadCustomAPIKey(identifier: keyIdentifier), !apiKey.isEmpty {
                let keyHeader = input["keyHeader"]?.stringValue ?? "Authorization"
                let keyPrefix = input["keyPrefix"]?.stringValue ?? ""
                headers[keyHeader] = "\(keyPrefix)\(apiKey)"
            }
        }

        // Build body
        let bodyData: Data?
        if let body = input["body"]?.stringValue, !body.isEmpty {
            bodyData = body.data(using: .utf8)
        } else {
            bodyData = nil
        }

        // Make request
        let response: HTTPResponse
        switch method.uppercased() {
        case "GET":
            response = try await httpClient.get(url, headers: headers)
        case "POST":
            response = try await httpClient.post(url, body: bodyData ?? Data(), headers: headers)
        case "PUT":
            response = try await httpClient.request(url, method: "PUT", body: bodyData, headers: headers)
        case "DELETE":
            response = try await httpClient.request(url, method: "DELETE", body: bodyData, headers: headers)
        default:
            throw SkillError.invalidInput("Méthode HTTP non supportée: \(method)")
        }

        context.emitEvent(.statusChanged("Réponse reçue: \(response.statusCode)"))

        // Parse response body as JSON if possible
        var bodyOutput: JSONValue = .string(response.body)
        if let data = response.body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) {
            bodyOutput = anyToJSONValue(json)
        }

        let output: JSONValue = .object([
            "statusCode": .number(Double(response.statusCode)),
            "body": bodyOutput,
            "headers": .object(response.headers.reduce(into: [String: JSONValue]()) { result, pair in
                result[pair.key] = .string(pair.value)
            })
        ])

        let success = response.isSuccess
        return SkillResult(
            output: output,
            summary: success ? "Appel API réussi (\(response.statusCode))" : "Appel API échoué (\(response.statusCode))",
            sources: []
        )
    }

    func requiresConfirmation(for input: JSONValue) -> Bool {
        let method = input["method"]?.stringValue ?? "GET"
        return method.uppercased() != "GET"
    }

    func confirmationDescription(for input: JSONValue) -> String {
        let method = input["method"]?.stringValue ?? "GET"
        let url = input["url"]?.stringValue ?? ""
        return "Appeler l'API \(method) sur \(url)?"
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
