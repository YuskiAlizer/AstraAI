import SwiftUI

/// History view — browse past conversations.
struct HistoryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var searchText = ""
    @State private var conversationToDelete: Conversation?

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return environment.conversations
        }
        return environment.conversations.filter {
            $0.title.lowercased().contains(searchText.lowercased()) ||
            $0.preview.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredConversations.isEmpty {
                        EmptyStateView(
                            icon: "clock",
                            title: "Aucune conversation",
                            message: "Vos conversations apparaîtront ici."
                        )
                    } else {
                        ForEach(filteredConversations) { conversation in
                            ConversationCardView(
                                conversation: conversation,
                                isSelected: environment.currentConversation?.id == conversation.id,
                                onTap: {
                                    environment.currentConversation = conversation
                                    environment.selectedTab = .chat
                                },
                                onDelete: {
                                    conversationToDelete = conversation
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Historique")
            .searchable(text: $searchText, prompt: "Rechercher...")
            .toolbar {
                if !environment.conversations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                Task {
                                    for conv in environment.conversations {
                                        try? environment.conversationStore.deleteConversation(id: conv.id)
                                    }
                                    await environment.loadConversations()
                                }
                            } label: {
                                Label("Tout supprimer", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Supprimer cette conversation?",
                isPresented: Binding(
                    get: { conversationToDelete != nil },
                    set: { if !$0 { conversationToDelete = nil } }
                ),
                presenting: conversationToDelete
            ) { conv in
                Button("Supprimer", role: .destructive) {
                    Task {
                        try? environment.conversationStore.deleteConversation(id: conv.id)
                        await environment.loadConversations()
                    }
                    conversationToDelete = nil
                }
                Button("Annuler", role: .cancel) {
                    conversationToDelete = nil
                }
            }
        }
    }
}

struct ConversationCardView: View {
    let conversation: Conversation
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(conversation.preview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.accentColor)
                    }
                }
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(conversation.messages.count) message(s)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(isSelected ? Color.accentColor.opacity(0.05) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contextMenu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
