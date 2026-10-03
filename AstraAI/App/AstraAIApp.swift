import SwiftUI

@main
struct AstraAIApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .preferredColorScheme(environment.theme.colorScheme)
        }
    }
}
