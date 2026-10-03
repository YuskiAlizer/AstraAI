import SwiftUI

/// Settings view — configure AI provider, API keys, theme, and view logs.
struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showAPIKeyEntry = false
    @State private var selectedProviderForKeys: AIProviderType?
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            Form {
                // AI Provider
                Section("Fournisseur IA") {
                    Picker("Fournisseur", selection: Binding(
                        get: { AIProviderType(rawValue: environment.providerSettings.selectedProviderId) ?? .openAI },
                        set: { newValue in
                            environment.providerSettings.setSelectedProvider(newValue.rawValue)
                        }
                    )) {
                        ForEach(AIProviderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    let currentType = AIProviderType(rawValue: environment.providerSettings.selectedProviderId) ?? .openAI

                    Picker("Modèle", selection: Binding(
                        get: { environment.providerSettings.selectedModelId(for: currentType.rawValue) },
                        set: { newValue in
                            environment.providerSettings.setSelectedModel(newValue, for: currentType.rawValue)
                        }
                    )) {
                        ForEach(currentType.models) { model in
                            Text(model.name).tag(model.id)
                        }
                    }

                    // API Key
                    Button {
                        selectedProviderForKeys = currentType
                        showAPIKeyEntry = true
                    } label: {
                        HStack {
                            Label(currentType.apiKeyName, systemImage: "key.fill")
                            Spacer()
                            if environment.secureKeyStore.loadAPIKey(for: currentType.rawValue) != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                // Custom Endpoint
                Section {
                    NavigationLink {
                        EndpointSettingsView(
                            providerId: environment.providerSettings.selectedProviderId,
                            settings: environment.providerSettings
                        )
                    } label: {
                        Label("Endpoint personnalisé", systemImage: "link")
                    }
                } header: {
                    Text("Endpoint")
                } footer: {
                    Text("Configurez un endpoint personnalisé pour utiliser un serveur proxy ou une API compatible.")
                }

                // API Keys Management
                Section("Clés API") {
                    NavigationLink {
                        APIKeysManagementView(
                            keyStore: environment.secureKeyStore
                        )
                    } label: {
                        Label("Gérer les clés API", systemImage: "lock.shield")
                    }
                }

                // Appearance
                Section("Apparence") {
                    Picker("Thème", selection: $environment.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                }

                // Data
                Section("Données") {
                    Button {
                        Task {
                            try? environment.conversationStore.deleteAllConversations()
                            await environment.loadConversations()
                        }
                    } label: {
                        Label("Supprimer toutes les conversations", systemImage: "trash")
                            .foregroundStyle(.red)
                    }

                    Button {
                        environment.memoryStore.deleteAll()
                    } label: {
                        Label("Supprimer tous les souvenirs", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                // Observability
                Section("Observabilité") {
                    NavigationLink {
                        LogsView(logger: environment.logger)
                    } label: {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
                }

                // About
                Section("À propos") {
                    LabeledContent("Application", value: "Astra AI")
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Plateforme", value: "iOS 17+")
                    LabeledContent("Technologie", value: "SwiftUI + Swift Concurrency")
                }
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $showAPIKeyEntry) {
                if let provider = selectedProviderForKeys {
                    APIKeyEntryView(
                        provider: provider,
                        keyStore: environment.secureKeyStore
                    )
                }
            }
        }
    }
}

// MARK: - API Key Entry

struct APIKeyEntryView: View {
    let provider: AIProviderType
    let keyStore: SecureKeyStore
    @State private var apiKey: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("\(provider.displayName) API Key") {
                    SecureField("Clé API", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if provider == .local {
                        Text("Ollama ne nécessite généralement pas de clé API. Laissez vide si vous utilisez le serveur local par défaut.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Enregistrer") {
                        keyStore.saveAPIKey(apiKey, for: provider.rawValue)
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty && provider != .local)
                }

                if keyStore.loadAPIKey(for: provider.rawValue) != nil {
                    Section {
                        Button("Supprimer la clé", role: .destructive) {
                            keyStore.deleteAPIKey(for: provider.rawValue)
                            apiKey = ""
                        }
                    }
                }
            }
            .navigationTitle(provider.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear {
                apiKey = keyStore.loadAPIKey(for: provider.rawValue) ?? ""
            }
        }
    }
}

// MARK: - API Keys Management

struct APIKeysManagementView: View {
    let keyStore: SecureKeyStore
    @State private var customKeyId = ""
    @State private var customKeyValue = ""
    @State private var savedKeys: [String] = []

    var body: some View {
        Form {
            Section("Clés API des fournisseurs") {
                ForEach(AIProviderType.allCases, id: \.self) { provider in
                    HStack {
                        Text(provider.displayName)
                        Spacer()
                        if keyStore.loadAPIKey(for: provider.rawValue) != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Non configurée")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Clés API personnalisées") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Identifiant (ex: brave_search)", text: $customKeyId)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    SecureField("Clé API", text: $customKeyValue)
                        .textFieldStyle(.roundedBorder)
                    Button("Enregistrer") {
                        guard !customKeyId.isEmpty && !customKeyValue.isEmpty else { return }
                        keyStore.saveCustomAPIKey(customKeyValue, identifier: customKeyId)
                        updateSavedKeys()
                        customKeyId = ""
                        customKeyValue = ""
                    }
                    .disabled(customKeyId.isEmpty || customKeyValue.isEmpty)
                }

                if !savedKeys.isEmpty {
                    ForEach(savedKeys, id: \.self) { keyId in
                        HStack {
                            Text(keyId)
                                .font(.subheadline)
                            Spacer()
                            Button(role: .destructive) {
                                keyStore.deleteCustomAPIKey(identifier: keyId)
                                updateSavedKeys()
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Clés API")
        .onAppear {
            updateSavedKeys()
        }
    }

    private func updateSavedKeys() {
        // We can't enumerate Keychain items directly, so we track known identifiers
        let knownIds = ["brave_search", "bing_search", "newsapi", "gnews", "code_backend_url"]
        savedKeys = knownIds.filter { keyStore.loadCustomAPIKey(identifier: $0) != nil }
    }
}

// MARK: - Endpoint Settings

struct EndpointSettingsView: View {
    let providerId: String
    @ObservedObject var settings: AIProviderSettings
    @State private var endpoint: String = ""

    var body: some View {
        Form {
            Section("Endpoint") {
                TextField("URL de l'endpoint", text: $endpoint)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            Section {
                Button("Enregistrer") {
                    settings.setCustomEndpoint(endpoint.isEmpty ? nil : endpoint, for: providerId)
                }
            }
        }
        .navigationTitle("Endpoint")
        .onAppear {
            endpoint = settings.customEndpoint(for: providerId) ?? ""
        }
    }
}

// MARK: - Logs View

struct LogsView: View {
    @ObservedObject var logger: AppLogger
    @State private var selectedLevel: AppLogger.Level? = nil

    var filteredEntries: [AppLogger.LogEntry] {
        guard let level = selectedLevel else { return logger.entries }
        return logger.entries.filter { $0.level == level }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                // Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("Tous") { selectedLevel = nil }
                            .font(.caption)
                            .padding(6)
                            .background(selectedLevel == nil ? Color.accentColor : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedLevel == nil ? .white : .primary)
                            .clipShape(Capsule())
                        ForEach(AppLogger.Level.allCases, id: \.self) { level in
                            Button(level.rawValue) { selectedLevel = level }
                                .font(.caption)
                                .padding(6)
                                .background(selectedLevel == level ? Color.accentColor : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedLevel == level ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }

                // Log entries
                ForEach(filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.level.icon)
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Text(entry.message)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    logger.clear()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}
