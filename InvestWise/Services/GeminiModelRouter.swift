import Foundation

// MARK: - Model Router

final class GeminiModelRouter {
    static let shared = GeminiModelRouter()

    private let rateLimiter = GeminiRateLimiter.shared

    /// Quality-ordered fallback chain.
    let fallbackChain: [GeminiModel] = GeminiModel.byQuality

    private init() {}

    /// Picks the first model in the fallback chain that has available quota.
    func selectModel() -> GeminiModel? {
        fallbackChain.first { rateLimiter.canUse($0) }
    }

    /// Returns all models that currently have available quota.
    func availableModels() -> [GeminiModel] {
        fallbackChain.filter { rateLimiter.canUse($0) }
    }

    /// Returns true when the preferred models (top 3) are >75% through their daily quota.
    /// This signals that prompts should be compacted to conserve remaining quota.
    func shouldCompactPrompt() -> Bool {
        let usage = rateLimiter.preferredModelsDailyUsage()
        guard !usage.isEmpty else { return true }
        let allAboveThreshold = usage.allSatisfy { entry in
            Double(entry.used) / Double(entry.limit) > 0.75
        }
        return allAboveThreshold
    }
}
