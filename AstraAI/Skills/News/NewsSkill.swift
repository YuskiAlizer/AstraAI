import Foundation

/// News Skill — fetches recent news articles via configurable news APIs.
/// Supports NewsAPI and GNews API. If no API key is configured, returns a clear error.
final class NewsSkill: AgentSkill, @unchecked Sendable {

    let id = "news"
    let name = "Actualités"
    let description = "Recherche les actualités récentes par sujet. Retourne le titre, l'URL, la source, la date et un extrait de chaque article."
    let category: SkillCategory = .news
    let requiredPermissions: [SkillPermission] = [.network]

    private let httpClient: HTTPClient
    private let keyStore: SecureKeyStore

    private let newsApiKeyId = "newsapi"
    private let gnewsApiKeyId = "gnews"

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Le sujet ou les mots-clés à rechercher")
                ]),
                "language": .object([
                    "type": .string("string"),
                    "description": .string("Code langue (ex: fr, en). Défaut: fr"),
                    "default": .string("fr")
                ]),
                "maxResults": .object([
                    "type": .string("number"),
                    "description": .string("Nombre maximum d'articles (défaut: 5)"),
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
                "articles": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "title": .string("Le titre de l'article"),
                            "url": .string("L'URL de l'article"),
                            "source": .string("Le nom de la source"),
                            "publishedAt": .string("La date de publication"),
                            "description": .string("Un extrait de l'article")
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

        let language = input["language"]?.stringValue ?? "fr"
        let maxResults = input["maxResults"]?.intValue ?? 5

        context.emitEvent(.statusChanged("Recherche d'actualités: \(query)..."))

        // Try NewsAPI first
        if let newsApiKey = await keyStore.loadCustomAPIKey(identifier: newsApiKeyId), !newsApiKey.isEmpty {
            return try await searchNewsAPI(query: query, language: language, maxResults: maxResults, apiKey: newsApiKey, context: context)
        }

        // Try GNews
        if let gnewsKey = await keyStore.loadCustomAPIKey(identifier: gnewsApiKeyId), !gnewsKey.isEmpty {
            return try await searchGNews(query: query, language: language, maxResults: maxResults, apiKey: gnewsKey, context: context)
        }

        throw SkillError.missingAPIKey(provider: "NewsAPI ou GNews. Configurez une clé API dans Paramètres > API.")
    }

    // MARK: - NewsAPI

    private func searchNewsAPI(query: String, language: String, maxResults: Int, apiKey: String, context: SkillExecutionContext) async throws -> SkillResult {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://newsapi.org/v2/everything?q=\(encodedQuery)&language=\(language)&sortBy=publishedAt&pageSize=\(maxResults)&apiKey=\(apiKey)"

        let response = try await httpClient.get(url)

        guard response.isSuccess else {
            throw SkillError.networkError("NewsAPI a retourné le code \(response.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let articles = json["articles"] as? [[String: Any]] else {
            throw SkillError.networkError("Réponse NewsAPI invalide")
        }

        var sources: [Source] = []
        var outputArticles: [[String: JSONValue]] = []

        for article in articles {
            let title = article["title"] as? String ?? ""
            let url = article["url"] as? String ?? ""
            let sourceName = (article["source"] as? [String: Any])?["name"] as? String ?? ""
            let publishedAt = article["publishedAt"] as? String ?? ""
            let description = article["description"] as? String ?? ""
            let domain = URL(string: url)?.host ?? sourceName

            let source = Source(title: title, url: url, snippet: description, date: publishedAt, domain: domain)
            sources.append(source)

            outputArticles.append([
                "title": .string(title),
                "url": .string(url),
                "source": .string(sourceName),
                "publishedAt": .string(publishedAt),
                "description": .string(description)
            ])
        }

        context.emitEvent(.statusChanged("Analyse de \(sources.count) articles..."))

        let output: JSONValue = .object([
            "query": .string(query),
            "articles": .array(outputArticles.map { .object($0) }),
            "total": .number(Double(sources.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(sources.count) article(s) trouvé(s) pour « \(query) »",
            sources: sources
        )
    }

    // MARK: - GNews

    private func searchGNews(query: String, language: String, maxResults: Int, apiKey: String, context: SkillExecutionContext) async throws -> SkillResult {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://gnews.io/api/v4/search?q=\(encodedQuery)&lang=\(language)&max=\(maxResults)&apikey=\(apiKey)"

        let response = try await httpClient.get(url)

        guard response.isSuccess else {
            throw SkillError.networkError("GNews a retourné le code \(response.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let articles = json["articles"] as? [[String: Any]] else {
            throw SkillError.networkError("Réponse GNews invalide")
        }

        var sources: [Source] = []
        var outputArticles: [[String: JSONValue]] = []

        for article in articles {
            let title = article["title"] as? String ?? ""
            let url = article["url"] as? String ?? ""
            let sourceName = (article["source"] as? [String: Any])?["name"] as? String ?? ""
            let publishedAt = article["publishedAt"] as? String ?? ""
            let description = article["description"] as? String ?? ""
            let domain = URL(string: url)?.host ?? sourceName

            let source = Source(title: title, url: url, snippet: description, date: publishedAt, domain: domain)
            sources.append(source)

            outputArticles.append([
                "title": .string(title),
                "url": .string(url),
                "source": .string(sourceName),
                "publishedAt": .string(publishedAt),
                "description": .string(description)
            ])
        }

        context.emitEvent(.statusChanged("Analyse de \(sources.count) articles..."))

        let output: JSONValue = .object([
            "query": .string(query),
            "articles": .array(outputArticles.map { .object($0) }),
            "total": .number(Double(sources.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(sources.count) article(s) trouvé(s) pour « \(query) »",
            sources: sources
        )
    }
}
