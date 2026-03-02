import Foundation

// MARK: - AI Provider

enum AIProvider: String, CaseIterable, Codable {
    case anthropic = "anthropic"
    case chipnemo = "chipnemo"
    case gemini = "gemini"

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Direct)"
        case .chipnemo: return "ChipNemo (NVIDIA)"
        case .gemini: return "Gemini (Google)"
        }
    }

    var keyLabel: String {
        switch self {
        case .anthropic: return "Anthropic API Key"
        case .chipnemo: return "NVAuth Token"
        case .gemini: return "Gemini API Key"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .chipnemo: return "NVAuth token"
        case .gemini: return "AIza..."
        }
    }

    var keychainKey: String {
        switch self {
        case .anthropic: return "claude_api_key"
        case .chipnemo: return "chipnemo_token"
        case .gemini: return "gemini_api_key"
        }
    }

    static let providerDefaultsKey = "ai_provider"
    static let chipnemoEndpointKey = "chipnemo_endpoint"
    static let chipnemoModelKey = "chipnemo_model"
}

// MARK: - Prompt Builder

struct StrategyPromptBuilder {
    static func buildPrompt(quotes: [MarketQuote], news: [NewsItem], redditPosts: [RedditPost], portfolio: Portfolio, compactMode: Bool = false) -> String {
        let newsLimit = compactMode ? 5 : 15
        let redditLimit = compactMode ? 3 : 10

        var prompt = """
        You are an investment strategy advisor. Analyze the following market data and provide actionable investment advice. For every reason you give, cite the specific data points (ticker symbols, price moves, news headlines, Reddit post titles) that led you to that conclusion.

        ## Portfolio Context
        - Total value: $\(Int(portfolio.totalValue)) USD
        - IBKR balance: $\(Int(portfolio.ibkrBalance)) | HSBC HK balance: $\(Int(portfolio.hsbcBalance))
        - Current allocation: Stocks \(portfolio.allocation.stocks)%, Bonds \(portfolio.allocation.bonds)%, Cash \(portfolio.allocation.cash)%, Alternatives \(portfolio.allocation.alternatives)%
        - Risk profile: Moderate (regular employee, core + tactical strategy)

        ## Current Market Data
        """
        for quote in quotes {
            let direction = quote.isPositive ? "+" : ""
            prompt += "\n- \(quote.symbol): $\(String(format: "%.2f", quote.price)) (\(direction)\(String(format: "%.2f", quote.changePercent))%)"
        }
        prompt += "\n\n## Recent News Headlines"
        for (i, item) in news.prefix(newsLimit).enumerated() {
            prompt += "\n\(i+1). [\(item.source)] \(item.title)"
        }
        prompt += "\n\n## Reddit Trending Discussions"
        for post in redditPosts.prefix(redditLimit) {
            prompt += "\n- [r/\(post.subreddit)] \(post.title) (score: \(post.score), comments: \(post.numComments))"
        }
        prompt += """

        \n\n## Instructions
        Respond ONLY with valid JSON matching this schema exactly:
        {
          "summary": "1-2 sentence actionable suggestion",
          "sentiment": "bullish" | "bearish" | "neutral",
          "confidence": 0.0-1.0,
          "reasons": [
            {
              "title": "short title",
              "explanation": "2-3 sentences explaining the reasoning",
              "type": "bullish" | "bearish" | "neutral",
              "confidence": "high" | "medium" | "low",
              "sources": ["SPY +0.58%", "Reuters: Fed holds rates", "r/wallstreetbets: SPY to the moon (score 1200)"]
            }
          ],
          "allocation": {"stocks": int, "bonds": int, "cash": int, "alternatives": int}
        }
        Rules:
        - The allocation percentages must sum to 100.
        - Provide as many reasons as the data supports (typically 3-8). Do not pad or limit to a fixed number.
        - Each reason MUST include a "sources" array citing the specific data points (market quotes, news headlines, Reddit posts) that support it. Use the exact values from the data above.
        """
        return prompt
    }
}

// MARK: - AI Service

final class AIService {
    private let session: URLSession
    private let keychain: KeychainService

    init(session: URLSession = .shared, keychain: KeychainService = KeychainService()) {
        self.session = session
        self.keychain = keychain
    }

    var currentProvider: AIProvider {
        guard let raw = UserDefaults.standard.string(forKey: AIProvider.providerDefaultsKey),
              let provider = AIProvider(rawValue: raw) else { return .gemini }
        return provider
    }

    var hasKey: Bool {
        guard let key = keychain.retrieve(key: currentProvider.keychainKey) else { return false }
        return !key.isEmpty
    }

    func fetchStrategy(quotes: [MarketQuote], news: [NewsItem], redditPosts: [RedditPost], portfolio: Portfolio) async throws -> (strategy: AIStrategy, modelUsed: String?) {
        let provider = currentProvider
        guard let apiKey = keychain.retrieve(key: provider.keychainKey), !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey(provider)
        }

        let text: String
        var modelUsed: String? = nil

        switch provider {
        case .anthropic:
            let prompt = StrategyPromptBuilder.buildPrompt(quotes: quotes, news: news, redditPosts: redditPosts, portfolio: portfolio)
            text = try await callAnthropic(prompt: prompt, apiKey: apiKey)
        case .chipnemo:
            let prompt = StrategyPromptBuilder.buildPrompt(quotes: quotes, news: news, redditPosts: redditPosts, portfolio: portfolio)
            text = try await callChipNemo(prompt: prompt, token: apiKey)
        case .gemini:
            let router = GeminiModelRouter.shared
            let compact = router.shouldCompactPrompt()
            let prompt = StrategyPromptBuilder.buildPrompt(quotes: quotes, news: news, redditPosts: redditPosts, portfolio: portfolio, compactMode: compact)
            let result = try await callGeminiWithFallback(prompt: prompt, apiKey: apiKey)
            text = result.text
            modelUsed = result.model.rawValue
        }
        return (try Self.parseResponse(text), modelUsed)
    }

    // MARK: - Anthropic Direct

    private func callAnthropic(prompt: String, apiKey: String) async throws -> String {
        let body: [String: Any] = [
            "model": "claude-sonnet-4-6-20250514",
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String
        else { throw AIServiceError.parseError(detail: "Unexpected Anthropic response structure") }
        return text
    }

    // MARK: - ChipNemo Proxy (OpenAI-compatible)

    private func callChipNemo(prompt: String, token: String) async throws -> String {
        let endpoint = UserDefaults.standard.string(forKey: AIProvider.chipnemoEndpointKey)
            ?? "https://chipnemo-models-api.nvidia.com/v1/internal/chipnemo/claude-opus-4-6"
        let model = UserDefaults.standard.string(forKey: AIProvider.chipnemoModelKey)
            ?? "us/aws/anthropic/us.anthropic.claude-opus-4-6"

        let baseURL = endpoint.hasSuffix("/chat/completions") ? endpoint : endpoint + "/chat/completions"
        guard let url = URL(string: baseURL) else { throw AIServiceError.invalidEndpoint }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String
        else { throw AIServiceError.parseError(detail: "Unexpected ChipNemo response structure") }
        return text
    }

    // MARK: - Gemini (single model call)

    private func callGeminiModel(_ model: GeminiModel, prompt: String, apiKey: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw AIServiceError.invalidEndpoint }
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)

        // Check for 429 specifically before general validation
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw AIServiceError.rateLimited(model: model.rawValue)
        }

        try validateHTTPResponse(response, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else { throw AIServiceError.parseError(detail: "Unexpected Gemini response structure") }
        return text
    }

    // MARK: - Gemini with fallback

    private func callGeminiWithFallback(prompt: String, apiKey: String) async throws -> (text: String, model: GeminiModel) {
        let rateLimiter = GeminiRateLimiter.shared
        let models = GeminiModelRouter.shared.availableModels()

        guard !models.isEmpty else {
            throw AIServiceError.allModelsExhausted
        }

        for model in models {
            do {
                let text = try await callGeminiModel(model, prompt: prompt, apiKey: apiKey)
                rateLimiter.recordSuccess(model)
                return (text, model)
            } catch AIServiceError.rateLimited {
                rateLimiter.recordRateLimited(model)
                continue
            }
        }

        throw AIServiceError.allModelsExhausted
    }

    // MARK: - Test Connection

    func testConnection() async -> (success: Bool, message: String) {
        let provider = currentProvider
        guard let apiKey = keychain.retrieve(key: provider.keychainKey), !apiKey.isEmpty else {
            return (false, "No API key configured for \(provider.displayName). Save your key first.")
        }

        let testPrompt = "Respond with exactly: {\"status\":\"ok\"}"
        do {
            switch provider {
            case .anthropic:
                _ = try await callAnthropic(prompt: testPrompt, apiKey: apiKey)
            case .chipnemo:
                _ = try await callChipNemo(prompt: testPrompt, token: apiKey)
            case .gemini:
                let result = try await callGeminiWithFallback(prompt: testPrompt, apiKey: apiKey)
                return (true, "\(provider.displayName) is reachable via \(result.model.displayName).")
            }
            return (true, "\(provider.displayName) is reachable and responding.")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.apiError(code: 0, body: "No HTTP response")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            let truncated = body.count > 500 ? String(body.prefix(500)) + "..." : body
            throw AIServiceError.apiError(code: http.statusCode, body: truncated)
        }
    }

    static func parseResponse(_ text: String) throws -> AIStrategy {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { throw AIServiceError.parseError(detail: "Could not encode to UTF-8") }
        do {
            return try JSONDecoder().decode(AIStrategy.self, from: data)
        } catch {
            let preview = cleaned.count > 300 ? String(cleaned.prefix(300)) + "..." : cleaned
            throw AIServiceError.parseError(detail: "JSON decode failed: \(error.localizedDescription)\nResponse preview: \(preview)")
        }
    }

    enum AIServiceError: Error, LocalizedError {
        case noAPIKey(AIProvider)
        case apiError(code: Int, body: String)
        case parseError(detail: String)
        case invalidEndpoint
        case rateLimited(model: String)
        case allModelsExhausted

        var errorDescription: String? {
            switch self {
            case .noAPIKey(let p):
                return "No \(p.displayName) key configured. Add it in Settings."
            case .apiError(let code, let body):
                return "HTTP \(code): \(body)"
            case .parseError(let detail):
                return "Parse error: \(detail)"
            case .invalidEndpoint:
                return "Invalid API endpoint URL."
            case .rateLimited(let model):
                return "Rate limited on \(model). Trying next model..."
            case .allModelsExhausted:
                return "All Gemini models exhausted their rate limits. Try again later."
            }
        }
    }
}

// MARK: - Legacy alias
typealias ClaudeAIService = AIService
