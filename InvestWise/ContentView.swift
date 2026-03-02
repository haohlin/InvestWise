import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var orchestrator: DataOrchestrator

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(AppState.Tab.dashboard)
            ReasonsView()
                .tabItem { Label("Reasons", systemImage: "lightbulb.fill") }
                .tag(AppState.Tab.reasons)
            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "briefcase.fill") }
                .tag(AppState.Tab.portfolio)
            MarketView()
                .tabItem { Label("Market", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppState.Tab.market)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppState.Tab.settings)
        }
        .tint(.teal)
        .overlay(alignment: .top) {
            if let error = orchestrator.error {
                errorBanner(error)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { orchestrator.error = nil }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataOrchestrator())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
