import XCTest
@testable import InvestWise

final class ClaudeAIServiceTests: XCTestCase {
    func testBuildPromptContainsPortfolioInfo() {
        let quotes = [MarketQuote(symbol: "SPY", price: 520, change: 3, changePercent: 0.58, previousClose: 517, timestamp: Date())]
        let news = [NewsItem(title: "Fed holds rates", source: "Reuters", url: "https://ex.com", publishedAt: Date(), description: nil)]
        let posts = [RedditPost(title: "SPY to the moon", selftext: "", score: 100, numComments: 50, permalink: "/r/test")]
        let portfolio = Portfolio(ibkrBalance: 80_000, hsbcBalance: 40_000, allocation: AssetAllocation(stocks: 60, bonds: 25, cash: 10, alternatives: 5))
        let prompt = StrategyPromptBuilder.buildPrompt(quotes: quotes, news: news, redditPosts: posts, portfolio: portfolio)
        XCTAssertTrue(prompt.contains("120,000") || prompt.contains("120000"))
        XCTAssertTrue(prompt.contains("IBKR"))
        XCTAssertTrue(prompt.contains("SPY"))
        XCTAssertTrue(prompt.contains("Fed holds rates"))
    }

    // MARK: - Rate Limiter Tests

    func testRateLimiterDailyCount() {
        let limiter = GeminiRateLimiter.shared
        limiter.resetAll()

        let model = GeminiModel.gemini25Flash
        XCTAssertEqual(limiter.dailyRequestCount(for: model), 0)

        limiter.recordSuccess(model)
        XCTAssertEqual(limiter.dailyRequestCount(for: model), 1)

        limiter.recordSuccess(model)
        XCTAssertEqual(limiter.dailyRequestCount(for: model), 2)

        limiter.resetAll()
    }

    // MARK: - Model Router Tests

    func testModelRouterReturnsFirstAvailable() {
        let limiter = GeminiRateLimiter.shared
        limiter.resetAll()

        let router = GeminiModelRouter.shared
        let selected = router.selectModel()
        XCTAssertEqual(selected, .gemini25Flash, "Should pick highest quality model when all available")

        limiter.resetAll()
    }

    // MARK: - Compact Prompt Tests

    func testCompactPromptIsShorter() {
        let quotes = [MarketQuote(symbol: "SPY", price: 520, change: 3, changePercent: 0.58, previousClose: 517, timestamp: Date())]
        var news: [NewsItem] = []
        for i in 0..<10 {
            news.append(NewsItem(title: "News headline \(i)", source: "Source", url: "https://ex.com/\(i)", publishedAt: Date(), description: nil))
        }
        var posts: [RedditPost] = []
        for i in 0..<5 {
            posts.append(RedditPost(title: "Reddit post \(i)", selftext: "", score: 100, numComments: 50, permalink: "/r/test/\(i)"))
        }
        let portfolio = Portfolio(ibkrBalance: 80_000, hsbcBalance: 40_000, allocation: AssetAllocation(stocks: 60, bonds: 25, cash: 10, alternatives: 5))

        let fullPrompt = StrategyPromptBuilder.buildPrompt(quotes: quotes, news: news, redditPosts: posts, portfolio: portfolio, compactMode: false)
        let compactPrompt = StrategyPromptBuilder.buildPrompt(quotes: quotes, news: news, redditPosts: posts, portfolio: portfolio, compactMode: true)

        XCTAssertTrue(compactPrompt.count < fullPrompt.count, "Compact prompt should be shorter than full prompt")
    }

    // MARK: - Parse Tests

    func testParseStrategyResponse() throws {
        let json = """
        {"summary":"Increase equity exposure","sentiment":"bullish","confidence":0.8,"top5reasons":[{"title":"Strong earnings","explanation":"Q4 beat expectations","type":"bullish","confidence":"high"},{"title":"Fed dovish","explanation":"Rate cuts likely","type":"bullish","confidence":"medium"},{"title":"Tech momentum","explanation":"AI spending up","type":"bullish","confidence":"high"},{"title":"Low volatility","explanation":"VIX below 15","type":"bullish","confidence":"medium"},{"title":"Global recovery","explanation":"PMI expanding","type":"bullish","confidence":"low"}],"allocation":{"stocks":65,"bonds":20,"cash":10,"alternatives":5}}
        """
        let strategy = try ClaudeAIService.parseResponse(json)
        XCTAssertEqual(strategy.top5reasons.count, 5)
        XCTAssertEqual(strategy.allocation.stocks, 65)
    }
}
