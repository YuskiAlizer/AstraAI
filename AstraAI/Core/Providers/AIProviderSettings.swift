import Foundation
import SwiftUI

/// Stores and manages AI provider settings (selected provider, model, endpoints).
/// Persisted to disk in Application Support.
@MainActor
final class AIProviderSettings: ObservableObject {

    @Published var selectedProviderId: String = AIProviderType.openAI.rawValue
    @Published var selectedModels: [String: String] = [:]
    @Published var customEndpoints: [String: String] = [:]

    private let fileURL: URL

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("provider_settings.json")
        load()
    }

    func selectedModelId(for providerId: String) -> String {
        if let model = selectedModels[providerId] { return model }
        // Default to first model for the provider type
        if let type = AIProviderType(rawValue: providerId) {
            return type.models.first?.id ?? ""
        }
        return ""
    }

    func setSelectedModel(_ modelId: String, for providerId: String) {
        selectedModels[providerId] = modelId
        save()
    }

    func customEndpoint(for providerId: String) -> String? {
        customEndpoints[providerId]
    }

    func setCustomEndpoint(_ endpoint: String?, for providerId: String) {
        if let endpoint, !endpoint.isEmpty {
            customEndpoints[providerId] = endpoint
        } else {
            customEndpoints.removeValue(forKey: providerId)
        }
        save()
    }

    func setSelectedProvider(_ providerId: String) {
        selectedProviderId = providerId
        save()
    }

    // MARK: - Persistence

    private struct PersistedData: Codable {
        var selectedProviderId: String
        var selectedModels: [String: String]
        var customEndpoints: [String: String]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let stored = try? decoder.decode(PersistedData.self, from: data) {
            self.selectedProviderId = stored.selectedProviderId
            self.selectedModels = stored.selectedModels
            self.customEndpoints = stored.customEndpoints
        }
    }

    private func save() {
        let data = PersistedData(
            selectedProviderId: selectedProviderId,
            selectedModels: selectedModels,
            customEndpoints: customEndpoints
        )
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }
}
