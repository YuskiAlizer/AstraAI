import SwiftUI

/// Root view with tab navigation.
struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        TabView(selection: $environment.selectedTab) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(AppTab.chat)

            VoiceView()
                .tabItem {
                    Label("Voix", systemImage: "mic")
                }
                .tag(AppTab.voice)

            SkillsView()
                .tabItem {
                    Label("Skills", systemImage: "cube.box")
                }
                .tag(AppTab.skills)

            MemoryView()
                .tabItem {
                    Label("Mémoire", systemImage: "brain.head.profile")
                }
                .tag(AppTab.memory)

            HistoryView()
                .tabItem {
                    Label("Historique", systemImage: "clock")
                }
                .tag(AppTab.history)

            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(Color.accentColor)
    }
}
