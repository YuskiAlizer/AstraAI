import Foundation

/// WebSearch Skill — performs internet searches via configurable search APIs.
/// Supports Brave Search API and Bing Search API.
/// If no API key is configured, returns a clear error to the user.
final class WebSearchSkill: AgentSkill, @unchecked Sendable {

    let id = "web_search"
    let name = "Recherche Web"
    let description = "Recherche des informations sur Internet. Retourne le titre, l'URL, un extrait, la date et la source de chaque résultat."
    let category: SkillCategory = .search
    let requiredPermissions: [SkillPermission] = [.network]

    private let httpClient: HTTPClient
    private let keyStore: SecureKeyStore

    // API key identifiers
    private let braveKeyId = "brave_search"
    private let bingKeyId = "bing_search"

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("La requête de recherche")
                ]),
                "count": .object([
                    "type": .string("number"),
                    "description": .string("Nombre de résultats (défaut: 5)"),
                    "default": .number(5)
                ])
            ]),
            "required": .array([.string("query")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "results": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "title": .string("Le titre du résultat"),
                            "url": .string("L'URL du résultat"),
                            "snippet": .string("Un extrait du contenu"),
                            "date": .string("La date de publication si disponible"),
                            "source": .string("Le domaine source")
                        ])
                    ])
                ])
            ])
        ])
    }

    init(httpClient: HTTPClient, keyStore: SecureKeyStore) {
        self.httpClient = httpClient
        self.keyStore = keyStore
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let query = input["query"]?.stringValue, !query.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'query' est requis")
        }

        let count = input["count"]?.intValue ?? 5

        context.emitEvent(.statusChanged("Recherche en cours: \(query)..."))

        // Try Brave Search first
        if let braveKey = await keyStore.loadCustomAPIKey(identifier: braveKeyId), !braveKey.isEmpty {
            return try await searchBrave(query: query, count: count, apiKey: braveKey, context: context)
        }

        // Try Bing Search
        if let bingKey = await keyStore.loadCustomAPIKey(identifier: bingKeyId), !bingKey.isEmpty {
            return try await searchBing(query: query, count: count, apiKey: bingKey, context: context)
        }

        throw SkillError.missingAPIKey(provider: "Brave Search ou Bing Search. Configurez une clé API dans Paramètres > API.")
    }

    // MARK: - Brave Search

    private func searchBrave(query: String, count: Int, apiKey: String, context: SkillExecutionContext) async throws -> SkillResult {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://api.search.brave.com/res/v1/web/search?q=\(encodedQuery)&count=\(count)"

        let headers = [
            "Accept": "application/json",
            "Accept-Encoding": "gzip",
            "X-Subscription-Token": apiKey
        ]

        let response = try await httpClient.get(url, headers: headers)

        guard response.isSuccess else {
            throw SkillError.networkError("Brave Search a retourné le code \(response.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let webResults = json["web"] as? [String: Any],
              let resultsArray = webResults["results"] as? [[String: Any]] else {
            throw SkillError.networkError("Réponse Brave invalide")
        }

        var sources: [Source] = []
        var outputResults: [[String: JSONValue]] = []

        for result in resultsArray {
            let title = result["title"] as? String ?? ""
            let url = result["url"] as? String ?? ""
            let snippet = result["description"] as? String ?? ""
            let date = result["age"] as? String
            let domain = URL(string: url)?.host ?? ""

            let source = Source(title: title, url: url, snippet: snippet, date: date, domain: domain)
            sources.append(source)

            outputResults.append([
                "title": .string(title),
                "url": .string(url),
                "snippet": .string(snippet),
                "date": .string(date ?? ""),
                "source": .string(domain)
            ])
        }

        context.emitEvent(.statusChanged("Analyse de \(sources.count) sources..."))

        let output: JSONValue = .object([
            "query": .string(query),
            "results": .array(outputResults.map { .object($0) }),
            "total": .number(Double(sources.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(sources.count) résultat(s) trouvé(s) pour « \(query) »",
            sources: sources
        )
    }

    // MARK: - Bing Search

    private func searchBing(query: String, count: Int, apiKey: String, context: SkillExecutionContext) async throws -> SkillResult {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://api.bing.microsoft.com/v7.0/search?q=\(encodedQuery)&count=\(count)"

        let headers = [
            "Ocp-Apim-Subscription-Key": apiKey
        ]

        let response = try await httpClient.get(url, headers: headers)

        guard response.isSuccess else {
            throw SkillError.networkError("Bing Search a retourné le code \(response.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let webPages = json["webPages"] as? [String: Any],
              let resultsArray = webPages["value"] as? [[String: Any]] else {
            throw SkillError.networkError("Réponse Bing invalide")
        }

        var sources: [Source] = []
        var outputResults: [[String: JSONValue]] = []

        for result in resultsArray {
            let title = result["name"] as? String ?? ""
            let url = result["url"] as? String ?? ""
            let snippet = result["snippet"] as? String ?? ""
            let date = result["dateLastCrawled"] as? String
            let domain = URL(string: url)?.host ?? ""

            let source = Source(title: title, url: url, snippet: snippet, date: date, domain: domain)
            sources.append(source)

            outputResults.append([
                "title": .string(title),
                "url": .string(url),
                "snippet": .string(snippet),
                "date": .string(date ?? ""),
                "source": .string(domain)
            ])
        }

        context.emitEvent(.statusChanged("Analyse de \(sources.count) sources..."))

        let output: JSONValue = .object([
            "query": .string(query),
            "results": .array(outputResults.map { .object($0) }),
            "total": .number(Double(sources.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(sources.count) résultat(s) trouvé(s) pour « \(query) »",
            sources: sources
        )
    }
}
