import SwiftUI

@main
struct InvestWiseApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var orchestrator = DataOrchestrator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(orchestrator)
                .preferredColorScheme(.dark)
        }
    }
}
