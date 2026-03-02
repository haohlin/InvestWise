import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .dashboard
    @Published var showingAPIKeyAlert = false

    let keychain = KeychainService()

    enum Tab: String, CaseIterable {
        case dashboard, reasons, portfolio, market, settings

        var title: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .reasons: return "lightbulb.fill"
            case .portfolio: return "briefcase.fill"
            case .market: return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var hasClaudeKey: Bool {
        keychain.retrieve(key: "claude_api_key") != nil
    }
}
