import SwiftUI

/// Memory view — browse, search, add, edit, and delete persistent memories.
struct MemoryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showAddSheet = false
    @State private var memoryToDelete: UserMemory?

    var filteredMemories: [UserMemory] {
        var memories = environment.memoryStore.memories

        if let category = selectedCategory {
            memories = memories.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            memories = environment.memoryStore.search(query: searchText)
        }

        return memories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedCategory = nil
                        } label: {
                            Text("Tous")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory == nil ? Color.accentColor : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedCategory == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        ForEach(environment.memoryStore.categories(), id: \.self) { category in
                            Button {
                                selectedCategory = selectedCategory == category ? nil : category
                            } label: {
                                Text(category)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Memories
                LazyVStack(spacing: 12) {
                    if filteredMemories.isEmpty {
                        EmptyStateView(
                            icon: "brain.head.profile",
                            title: "Aucun souvenir",
                            message: "L'agent mémorisera automatiquement les informations importantes que vous lui donnez."
                        )
                    } else {
                        ForEach(filteredMemories) { memory in
                            MemoryCardView(
                                memory: memory,
                                onDelete: {
                                    memoryToDelete = memory
                                },
                                onEdit: { newValue in
                                    environment.memoryStore.update(id: memory.id, value: newValue)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Mémoire")
            .searchable(text: $searchText, prompt: "Rechercher dans la mémoire...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddMemoryView { category, key, value in
                    environment.memoryStore.add(category: category, key: key, value: value)
                    showAddSheet = false
                }
            }
            .confirmationDialog(
                "Supprimer ce souvenir?",
                isPresented: Binding(
                    get: { memoryToDelete != nil },
                    set: { if !$0 { memoryToDelete = nil } }
                ),
                presenting: memoryToDelete
            ) { memory in
                Button("Supprimer", role: .destructive) {
                    environment.memoryStore.delete(id: memory.id)
                    memoryToDelete = nil
                }
                Button("Annuler", role: .cancel) {
                    memoryToDelete = nil
                }
            }
        }
    }
}

struct MemoryCardView: View {
    let memory: UserMemory
    let onDelete: () -> Void
    let onEdit: (String) -> Void
    @State private var isEditing = false
    @State private var editValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(memory.category)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(.accentColor)
                            .clipShape(Capsule())

                        Text(memory.key)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if isEditing {
                        TextField("Valeur", text: $editValue, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    } else {
                        Text(memory.value)
                            .font(.body)
                    }
                }
                Spacer()
                Menu {
                    Button {
                        editValue = memory.value
                        isEditing = true
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    if isEditing {
                        Button {
                            onEdit(editValue)
                            isEditing = false
                        } label: {
                            Label("Enregistrer", systemImage: "checkmark")
                        }
                        Button("Annuler", role: .cancel) {
                            isEditing = false
                        }
                    }
                    Divider()
                    Button("Supprimer", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Mis à jour: \(memory.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AddMemoryView: View {
    @State private var category = ""
    @State private var key = ""
    @State private var value = ""
    let onAdd: (String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Souvenir") {
                    TextField("Catégorie (ex: préférences)", text: $category)
                    TextField("Clé (ex: couleur_préférée)", text: $key)
                    TextField("Valeur", text: $value, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Nouveau souvenir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        guard !category.isEmpty && !key.isEmpty && !value.isEmpty else { return }
                        onAdd(category, key, value)
                    }
                    .disabled(category.isEmpty || key.isEmpty || value.isEmpty)
                }
            }
        }
    }
}
