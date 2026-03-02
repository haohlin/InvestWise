import Combine
import Foundation

struct DiagnosticLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let source: String
    let message: String
    let isError: Bool
}

@MainActor
final class DataOrchestrator: ObservableObject {
    @Published var quotes: [MarketQuote] = []
    @Published var news: [NewsItem] = []
    @Published var redditPosts: [RedditPost] = []
    @Published var strategy: AIStrategy?
    @Published var sentimentScore: Double = 0
    @Published var sentimentLabel: AIStrategy.Sentiment = .neutral
    @Published var isLoading = false
    @Published var error: String?
    @Published var diagnosticLogs: [DiagnosticLog] = []
    @Published var lastGeminiModel: String?

    let aiService: AIService
    private let marketDataService: MarketDataService
    private let newsService: NewsService
    private let redditService: RedditService
    private let cacheManager: CacheManager?

    var portfolio: Portfolio {
        Portfolio(
            ibkrBalance: ibkrBalance,
            hsbcBalance: hsbcBalance,
            allocation: strategy?.allocation ?? AssetAllocation(stocks: 60, bonds: 20, cash: 10, alternatives: 10)
        )
    }

    @Published var ibkrBalance: Double = 50000
    @Published var hsbcBalance: Double = 30000

    init(keychain: KeychainService = KeychainService()) {
        self.marketDataService = MarketDataService()
        self.newsService = NewsService(apiKey: { keychain.retrieve(key: "newsapi_key") })
        self.redditService = RedditService()
        self.aiService = AIService(keychain: keychain)
        self.cacheManager = try? CacheManager()
        loadCachedData()
    }

    func log(_ source: String, _ message: String, isError: Bool = false) {
        let entry = DiagnosticLog(source: source, message: message, isError: isError)
        diagnosticLogs.insert(entry, at: 0)
        if diagnosticLogs.count > 50 { diagnosticLogs.removeLast() }
    }

    /// Fetch market data, news, reddit independently (failures are non-fatal).
    /// Does NOT call AI — use analyzeWithAI() separately.
    func refreshData() async {
        isLoading = true
        error = nil
        log("Refresh", "Fetching market data, news, reddit...")

        // Fetch market data (non-fatal)
        do {
            let q = try await marketDataService.fetchQuotes()
            quotes = q
            try? cacheManager?.cacheMarketQuotes(q)
            log("Market", "Fetched \(q.count) quotes")
        } catch is CancellationError {
            log("Market", "Cancelled — using cached data", isError: true)
        } catch {
            log("Market", "Failed: \(error.localizedDescription)", isError: true)
        }

        // Fetch news (non-fatal)
        do {
            let n = try await newsService.fetchNews()
            news = n.map { item in
                var tagged = item
                tagged.sentimentTag = SentimentService.tagSentiment(item.title + " " + (item.description ?? ""))
                return tagged
            }
            try? cacheManager?.cacheNews(n)
            log("News", "Fetched \(n.count) articles")
        } catch is CancellationError {
            log("News", "Cancelled — using cached data", isError: true)
        } catch {
            log("News", "Failed: \(error.localizedDescription)", isError: true)
        }

        // Fetch reddit (non-fatal)
        do {
            let r = try await redditService.fetchTrending()
            redditPosts = r
            log("Reddit", "Fetched \(r.count) posts")
        } catch is CancellationError {
            log("Reddit", "Cancelled — using cached data", isError: true)
        } catch {
            log("Reddit", "Failed: \(error.localizedDescription)", isError: true)
        }

        // Compute sentiment from whatever data we have
        let sentiment = SentimentService.aggregateSentiment(news: news, redditPosts: redditPosts)
        sentimentScore = sentiment.score
        sentimentLabel = sentiment.label
        isLoading = false
    }

    /// Call the AI provider to generate strategy. Call this explicitly — never auto.
    @Published var isAnalyzing = false

    func analyzeWithAI() async {
        let provider = aiService.currentProvider
        guard aiService.hasKey else {
            self.error = "No \(provider.displayName) key configured. Add it in Settings."
            log("AI", "Skipped — no API key for \(provider.displayName)", isError: true)
            return
        }
        isAnalyzing = true
        log("AI", "Requesting strategy from \(provider.displayName)...")
        do {
            let result = try await aiService.fetchStrategy(
                quotes: quotes, news: news, redditPosts: redditPosts, portfolio: portfolio
            )
            strategy = result.strategy
            lastGeminiModel = result.modelUsed
            try? cacheManager?.cacheStrategy(result.strategy)
            let modelInfo = result.modelUsed.map { " via \($0)" } ?? ""
            log("AI", "Strategy received\(modelInfo) — sentiment: \(result.strategy.sentiment.rawValue), confidence: \(Int(result.strategy.confidence * 100))%")
        } catch is CancellationError {
            log("AI", "Request cancelled by system", isError: true)
            self.error = "AI request was cancelled. Try again."
        } catch {
            log("AI", "Failed: \(error.localizedDescription)", isError: true)
            self.error = error.localizedDescription
        }
        isAnalyzing = false
    }

    private func loadCachedData() {
        quotes = (try? cacheManager?.loadCachedQuotes()) ?? []
        news = (try? cacheManager?.loadCachedNews()) ?? []
        strategy = try? cacheManager?.loadCachedStrategy()
    }
}
