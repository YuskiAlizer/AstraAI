import Foundation

/// WebBrowser Skill — fetches and analyzes web page content.
/// Uses URLSession to retrieve HTML content. Does NOT execute JavaScript
/// or bypass paywalls, login walls, or other access restrictions.
final class WebBrowserSkill: AgentSkill, @unchecked Sendable {

    let id = "web_browser"
    let name = "Navigateur Web"
    let description = "Ouvre une page web, récupère son contenu texte et l'analyse. Peut suivre des liens si nécessaire."
    let category: SkillCategory = .browser
    let requiredPermissions: [SkillPermission] = [.network]

    private let httpClient: HTTPClient

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("L'URL de la page à analyser")
                ]),
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action à effectuer: 'fetch' (récupérer le contenu) ou 'analyze' (analyser)"),
                    "enum": .array([.string("fetch"), .string("analyze")]),
                    "default": .string("fetch")
                ])
            ]),
            "required": .array([.string("url")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "url": .string("L'URL analysée"),
                "title": .string("Le titre de la page"),
                "content": .string("Le contenu texte de la page"),
                "links": .array([.string("Liens trouvés sur la page")])
            ])
        ])
    }

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let urlString = input["url"]?.stringValue, !urlString.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'url' est requis")
        }

        guard let url = URL(string: urlString) else {
            throw SkillError.invalidInput("URL invalide: \(urlString)")
        }

        let action = input["action"]?.stringValue ?? "fetch"

        context.emitEvent(.statusChanged("Récupération de la page: \(url.host ?? url.absoluteString)..."))

        let response = try await httpClient.get(url.absoluteString, headers: [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.8",
            "User-Agent": "AstraAI/1.0 (iOS)"
        ])

        guard response.isSuccess else {
            throw SkillError.networkError("Erreur HTTP \(response.statusCode) lors de la récupération de la page")
        }

        // Extract text content from HTML
        let html = response.body
        let title = extractTitle(from: html)
        let textContent = extractTextContent(from: html)
        let links = extractLinks(from: html, baseURL: url)

        context.emitEvent(.statusChanged("Page analysée: \(title)"))

        let output: JSONValue = .object([
            "url": .string(url.absoluteString),
            "title": .string(title),
            "content": .string(textContent),
            "links": .array(links.map { .string($0) })
        ])

        return SkillResult(
            output: output,
            summary: "Page « \(title) » récupérée (\(textContent.count) caractères)",
            sources: [Source(title: title, url: url.absoluteString, snippet: String(textContent.prefix(200)), domain: url.host ?? "")]
        )
    }

    // MARK: - HTML Parsing

    private func extractTitle(from html: String) -> String {
        guard let startTag = html.range(of: "<title", options: .caseInsensitive),
              let startContent = html.range(of: ">", range: startTag.upperBound..<html.endIndex) else {
            return ""
        }
        guard let endTag = html.range(of: "</title>", options: .caseInsensitive, range: startContent.upperBound..<html.endIndex) else {
            return ""
        }
        return String(html[startContent.upperBound..<endTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextContent(from html: String) -> String {
        var text = html

        // Remove scripts and styles
        text = removeTag(text, "script")
        text = removeTag(text, "style")
        text = removeTag(text, "nav")
        text = removeTag(text, "footer")
        text = removeTag(text, "header")

        // Remove HTML tags
        var result = ""
        var insideTag = false
        for char in text {
            if char == "<" {
                insideTag = true
            } else if char == ">" {
                insideTag = false
            } else if !insideTag {
                result.append(char)
            }
        }

        // Clean up whitespace
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")

        // Collapse multiple whitespace
        let components = result.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    private func removeTag(_ text: String, _ tag: String) -> String {
        var result = text
        while let startRange = result.range(of: "<\(tag)", options: .caseInsensitive) {
            guard let endRange = result.range(of: "</\(tag)>", options: .caseInsensitive, range: startRange.upperBound..<result.endIndex) else {
                break
            }
            result.removeSubrange(startRange.lowerBound..<endRange.upperBound)
        }
        return result
    }

    private func extractLinks(from html: String, baseURL: URL) -> [String] {
        var links: [String] = []
        var current = html

        while let hrefRange = current.range(of: "href=\"") {
            let afterHref = hrefRange.upperBound
            guard let endQuote = current.range(of: "\"", range: afterHref..<current.endIndex) else { break }

            let link = String(current[afterHref..<endQuote.lowerBound])

            if link.hasPrefix("http") {
                links.append(link)
            } else if link.hasPrefix("/") {
                if let base = baseURL.scheme, let host = baseURL.host {
                    links.append("\(base)://\(host)\(link)")
                }
            }

            current = String(current[endQuote.upperBound...])
        }

        return Array(links.prefix(20)) // Limit to 20 links
    }
}
