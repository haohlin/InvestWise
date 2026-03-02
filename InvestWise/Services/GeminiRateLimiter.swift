import Foundation

// MARK: - Gemini Model

enum GeminiModel: String, CaseIterable {
    case gemini25Flash = "gemini-2.5-flash"
    case gemini3Flash = "gemini-3-flash"
    case gemini25FlashLite = "gemini-2.5-flash-lite"
    case gemma327b = "gemma-3-27b-it"
    case gemma312b = "gemma-3-12b-it"

    var displayName: String { rawValue }

    var rpm: Int {
        switch self {
        case .gemini25Flash, .gemini3Flash: return 5
        case .gemini25FlashLite: return 10
        case .gemma327b, .gemma312b: return 30
        }
    }

    var tpm: Int {
        switch self {
        case .gemini25Flash, .gemini3Flash, .gemini25FlashLite: return 250_000
        case .gemma327b, .gemma312b: return 15_000
        }
    }

    var rpd: Int {
        switch self {
        case .gemini25Flash, .gemini3Flash, .gemini25FlashLite: return 20
        case .gemma327b, .gemma312b: return 14_400
        }
    }

    /// Higher = better quality. Used for fallback ordering.
    var qualityTier: Int {
        switch self {
        case .gemini25Flash: return 5
        case .gemini3Flash: return 4
        case .gemini25FlashLite: return 3
        case .gemma327b: return 2
        case .gemma312b: return 1
        }
    }

    /// Models ordered by quality (best first).
    static var byQuality: [GeminiModel] {
        allCases.sorted { $0.qualityTier > $1.qualityTier }
    }
}

// MARK: - Rate Limiter

final class GeminiRateLimiter {
    static let shared = GeminiRateLimiter()

    private let defaults = UserDefaults.standard
    private let lock = NSLock()

    private init() {}

    // MARK: - Keys

    private func rpmTimestampsKey(_ model: GeminiModel) -> String {
        "gemini_rpm_\(model.rawValue)"
    }

    private func rpdCountKey(_ model: GeminiModel) -> String {
        "gemini_rpd_count_\(model.rawValue)"
    }

    private func rpdDateKey(_ model: GeminiModel) -> String {
        "gemini_rpd_date_\(model.rawValue)"
    }

    private func backoffUntilKey(_ model: GeminiModel) -> String {
        "gemini_backoff_\(model.rawValue)"
    }

    // MARK: - RPM (sliding window of timestamps)

    private func recentTimestamps(for model: GeminiModel) -> [TimeInterval] {
        let key = rpmTimestampsKey(model)
        let stored = defaults.array(forKey: key) as? [TimeInterval] ?? []
        let cutoff = Date().timeIntervalSince1970 - 60
        return stored.filter { $0 > cutoff }
    }

    // MARK: - RPD (count + date, auto-resets daily)

    func dailyRequestCount(for model: GeminiModel) -> Int {
        lock.lock()
        defer { lock.unlock() }
        resetDailyIfNeeded(model)
        return defaults.integer(forKey: rpdCountKey(model))
    }

    private func resetDailyIfNeeded(_ model: GeminiModel) {
        let dateKey = rpdDateKey(model)
        let today = Calendar.current.startOfDay(for: Date())
        if let stored = defaults.object(forKey: dateKey) as? Date,
           Calendar.current.isDate(stored, inSameDayAs: today) {
            return
        }
        defaults.set(0, forKey: rpdCountKey(model))
        defaults.set(today, forKey: dateKey)
    }

    // MARK: - Backoff (429 cooldown)

    private func isBackedOff(_ model: GeminiModel) -> Bool {
        let until = defaults.double(forKey: backoffUntilKey(model))
        guard until > 0 else { return false }
        return Date().timeIntervalSince1970 < until
    }

    // MARK: - Public API

    func canUse(_ model: GeminiModel) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if isBackedOff(model) { return false }

        resetDailyIfNeeded(model)
        let daily = defaults.integer(forKey: rpdCountKey(model))
        if daily >= model.rpd { return false }

        let recent = recentTimestamps(for: model)
        if recent.count >= model.rpm { return false }

        return true
    }

    func recordSuccess(_ model: GeminiModel) {
        lock.lock()
        defer { lock.unlock() }

        // RPM
        var timestamps = recentTimestamps(for: model)
        timestamps.append(Date().timeIntervalSince1970)
        defaults.set(timestamps, forKey: rpmTimestampsKey(model))

        // RPD
        resetDailyIfNeeded(model)
        let count = defaults.integer(forKey: rpdCountKey(model))
        defaults.set(count + 1, forKey: rpdCountKey(model))
    }

    func recordRateLimited(_ model: GeminiModel) {
        lock.lock()
        defer { lock.unlock() }

        let backoffUntil = Date().timeIntervalSince1970 + 65
        defaults.set(backoffUntil, forKey: backoffUntilKey(model))
    }

    /// Returns daily usage for the preferred models (top 3 by quality).
    func preferredModelsDailyUsage() -> [(model: GeminiModel, used: Int, limit: Int)] {
        GeminiModel.byQuality.prefix(3).map { model in
            (model: model, used: dailyRequestCount(for: model), limit: model.rpd)
        }
    }

    /// Reset all tracking data (useful for testing).
    func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        for model in GeminiModel.allCases {
            defaults.removeObject(forKey: rpmTimestampsKey(model))
            defaults.removeObject(forKey: rpdCountKey(model))
            defaults.removeObject(forKey: rpdDateKey(model))
            defaults.removeObject(forKey: backoffUntilKey(model))
        }
    }
}
