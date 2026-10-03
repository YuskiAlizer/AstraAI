import SwiftUI

/// Chat view — the main conversation interface.
struct ChatView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var inputText: String = ""
    @State private var showImagePicker = false
    @State private var showFilePicker = false
    @State private var showConfirmation = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if let conversation = environment.currentConversation {
                                ForEach(conversation.messages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }
                            }

                            // Streaming text
                            if !environment.agentCore.streamingText.isEmpty {
                                StreamingBubbleView(text: environment.agentCore.streamingText)
                                    .id("streaming")
                            }

                            // Status indicator
                            if environment.agentCore.runState.isRunning {
                                StatusIndicatorView(
                                    status: environment.agentCore.runState.statusText ?? "",
                                    events: environment.agentCore.events.suffix(3)
                                )
                                .id("status")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onChange(of: environment.agentCore.streamingText) { _, _ in
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                    .onChange(of: environment.currentConversation?.messages.count) { _, _ in
                        withAnimation {
                            if let lastMsg = environment.currentConversation?.messages.last {
                                proxy.scrollTo(lastMsg.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Sources
                if !environment.agentCore.currentSources.isEmpty {
                    SourcesView(sources: environment.agentCore.currentSources)
                }

                // Input bar
                inputBar
            }
            .navigationTitle(environment.currentConversation?.title ?? "Astra AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await environment.startNewConversation() }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }

                if environment.agentCore.runState.isRunning {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            environment.agentCore.cancel()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showConfirmation) {
            if let confirmation = environment.agentCore.pendingConfirmation {
                ConfirmationView(
                    request: confirmation,
                    onApprove: {
                        environment.agentCore.resolveConfirmation(confirmation, approved: true)
                        showConfirmation = false
                    },
                    onDeny: {
                        environment.agentCore.resolveConfirmation(confirmation, approved: false)
                        showConfirmation = false
                    }
                )
            }
        }
        .onChange(of: environment.agentCore.pendingConfirmation) { _, newValue in
            showConfirmation = newValue != nil
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Attachments
                Menu {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Image", systemImage: "photo")
                    }
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Fichier", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // Text field
                TextField("Demandez quelque chose à Astra...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }

                // Microphone
                Button {
                    environment.selectedTab = .voice
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.accentColor)
                }

                // Send button
                if !inputText.isEmpty {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.accentColor)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 0.5), alignment: .top)
        }
        .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { attachment in
                // Handle image attachment
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView { attachment in
                // Handle file attachment
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let message = inputText
        inputText = ""
        inputFocused = false

        guard var conversation = environment.currentConversation else { return }
        environment.agentCore.run(userMessage: message, conversation: &conversation)
        environment.currentConversation = conversation
    }
}

// MARK: - Chat ViewModel

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: AgentMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Role label
                if message.role == .assistant {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.accentColor)
                        Text("Astra AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Content
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(message.role == .user ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.role == .user ?
                            AnyShapeStyle(Color.accentColor) :
                            AnyShapeStyle(Color(.secondarySystemBackground))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Tool calls
                if !message.toolCalls.isEmpty {
                    ForEach(message.toolCalls) { call in
                        ToolCallView(toolCall: call)
                    }
                }

                // Sources
                if !message.sources.isEmpty {
                    SourcesView(sources: message.sources)
                }

                // Timestamp
                Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Streaming Bubble

struct StreamingBubbleView: View {
    let text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.accentColor)
                    Text("Astra AI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(text)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.6)
                                    .animation(
                                        .easeInOut(duration: 0.5)
                                        .repeatForever()
                                        .delay(Double(i) * 0.2),
                                        value: true
                                    )
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 8),
                        alignment: .bottomTrailing
                    )
            }
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Status Indicator

struct StatusIndicatorView: View {
    let status: String
    let events: [AgentEvent]

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}

// MARK: - Sources

struct SourcesView: View {
    let sources: [Source]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(sources.prefix(5)) { source in
                Link(destination: URL(string: source.url) ?? URL(string: "https://example.com")!) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        Text(source.domain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCall

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForStatus)
                .font(.caption)
                .foregroundStyle(colorForStatus)
            VStack(alignment: .leading, spacing: 2) {
                Text(toolCall.name)
                    .font(.caption)
                    .fontWeight(.medium)
                if let error = toolCall.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var iconForStatus: String {
        switch toolCall.status {
        case .pending: return "clock"
        case .executing: return "gear"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "xmark"
        case .awaitingConfirmation: return "questionmark.circle"
        }
    }

    private var colorForStatus: Color {
        switch toolCall.status {
        case .pending: return .gray
        case .executing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        case .awaitingConfirmation: return .orange
        }
    }
}

// MARK: - Confirmation View

struct ConfirmationView: View {
    let request: ConfirmationRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(.accentColor)

                Text("Confirmation requise")
                    .font(.headline)

                Text(request.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Skill", value: request.skillName)
                    LabeledContent("Action", value: request.action)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onApprove()
                    } label: {
                        Text("Autoriser")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button("Refuser", role: .destructive) {
                        onDeny()
                    }
                    .font(.headline)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Sécurité")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Pickers

struct ImagePickerView: View {
    let onPick: (Attachment) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Sélection d'image")
                    .font(.headline)
                    .padding()

                Text("Utilisez le bouton ci-dessous pour sélectionner une image depuis votre photothèque.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

struct DocumentPickerView: View {
    let onPick: (Attachment) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Sélection de fichier")
                    .font(.headline)
                    .padding()

                Text("Utilisez le sélecteur de documents iOS pour choisir un fichier.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Fichier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}
