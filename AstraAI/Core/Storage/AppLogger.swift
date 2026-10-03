import Foundation
import os.log

/// Centralized logging system. Uses os.Logger for system-level logging
/// and maintains an in-memory buffer for the UI observability view.
/// NEVER logs API keys or sensitive data.
@MainActor
final class AppLogger: ObservableObject {

    static let shared = AppLogger()

    enum Level: String, CaseIterable {
        case debug, info, warning, error

        var icon: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }

    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let message: String
    }

    @Published private(set) var entries: [LogEntry] = []

    private let osLog = Logger(subsystem: "com.astraai.app", category: "agent")
    private let maxEntries = 500

    private init() {}

    // MARK: - Public

    func debug(_ message: String) {
        log(.debug, message)
    }

    func info(_ message: String) {
        log(.info, message)
    }

    func warning(_ message: String) {
        log(.warning, message)
    }

    func error(_ message: String) {
        log(.error, message)
    }

    func clear() {
        entries.removeAll()
    }

    // MARK: - Private

    private func log(_ level: Level, _ message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        entries.append(entry)

        // Trim old entries
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        // Also log to system log (for Console.app / device logs)
        switch level {
        case .debug:
            osLog.debug("\(message, privacy: .public)")
        case .info:
            osLog.info("\(message, privacy: .public)")
        case .warning:
            osLog.warning("\(message, privacy: .public)")
        case .error:
            osLog.error("\(message, privacy: .public)")
        }
    }
}
