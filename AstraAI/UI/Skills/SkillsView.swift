import SwiftUI

/// Skills view — shows all available skills and allows enabling/disabling.
struct SkillsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var searchText = ""
    @State private var selectedCategory: SkillCategory?

    var filteredSkills: [AgentSkill] {
        var skills = environment.skillRegistry.allSkills

        if let category = selectedCategory {
            skills = skills.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            skills = skills.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.description.lowercased().contains(searchText.lowercased())
            }
        }

        return skills
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(category: nil, selected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(SkillCategory.allCases, id: \.self) { category in
                            CategoryChip(category: category, selected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Skills list
                LazyVStack(spacing: 12) {
                    ForEach(filteredSkills, id: \.id) { skill in
                        SkillCardView(
                            skill: skill,
                            isEnabled: environment.skillSettingsStore.isEnabled(skillId: skill.id),
                            onToggle: {
                                environment.skillSettingsStore.toggle(skillId: skill.id)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Skills")
            .searchable(text: $searchText, prompt: "Rechercher un skill...")
        }
    }
}

struct CategoryChip: View {
    let category: SkillCategory?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category?.iconName ?? "sparkles")
                    .font(.caption)
                Text(category?.displayName ?? "Tous")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(selected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct SkillCardView: View {
    let skill: AgentSkill
    let isEnabled: Bool
    let onToggle: () -> Void

    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: skill.category.iconName)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }

                // Title and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.headline)
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Toggle
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(Color.accentColor)
            }

            // Permissions
            if !skill.requiredPermissions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(skill.requiredPermissions.map { $0.description }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Expandable details
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Catégorie").font(.caption).fontWeight(.semibold)
                        Text(skill.category.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirmation requise").font(.caption).fontWeight(.semibold)
                        Text(skill.requiresConfirmation ? "Oui" : "Non").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schéma d'entrée").font(.caption).fontWeight(.semibold)
                        Text(skill.inputSchema.jsonString())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            withAnimation { showDetails.toggle() }
        }
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}
