import Foundation

/// A lightweight HTTP client wrapping URLSession with timeout, retry,
/// and error handling. Never logs sensitive headers or bodies.
final class HTTPClient: @unchecked Sendable {

    private let session: URLSession
    private let maxRetries: Int
    private let logger = AppLogger.shared

    init(maxRetries: Int = 2) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        self.maxRetries = maxRetries
    }

    // MARK: - Public

    func get(_ urlString: String, headers: [String: String] = [:]) async throws -> HTTPResponse {
        guard let url = URL(string: urlString) else {
            throw HTTPError.invalidURL
        }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        request.httpMethod = "GET"
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        return try await sendWithRetry(request: request)
    }

    func post(_ urlString: String, body: Data, headers: [String: String] = [:]) async throws -> HTTPResponse {
        guard let url = URL(string: urlString) else {
            throw HTTPError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        return try await sendWithRetry(request: request)
    }

    func request(_ urlString: String, method: String, body: Data? = nil, headers: [String: String] = [:]) async throws -> HTTPResponse {
        guard let url = URL(string: urlString) else {
            throw HTTPError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        return try await sendWithRetry(request: req)
    }

    // MARK: - Private

    private func sendWithRetry(request: URLRequest) async throws -> HTTPResponse {
        var lastError: Error = HTTPError.networkError(underlying: nil)

        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HTTPError.invalidResponse
                }
                let body = String(data: data, encoding: .utf8) ?? ""
                logger.debug("HTTP \(httpResponse.statusCode) \(request.url?.path ?? "")")
                return HTTPResponse(
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                    body: body,
                    data: data
                )
            } catch {
                lastError = HTTPError.networkError(underlying: error)
                if attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 500_000_000
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw lastError
    }
}

// MARK: - Response & Error

struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: String
    let data: Data

    var isSuccess: Bool { statusCode >= 200 && statusCode < 300 }

    func decodeJSON<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }
}

enum HTTPError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(underlying: Error?)
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .networkError:
            return "Erreur réseau"
        case .httpError(let code, let body):
            return "Erreur HTTP \(code): \(body.prefix(200))"
        }
    }
}
