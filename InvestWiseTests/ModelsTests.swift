import XCTest
@testable import InvestWise

final class ModelsTests: XCTestCase {
    func testMarketDataDecoding() throws {
        let json = """
        {"symbol":"SPY","price":520.50,"change":3.20,"changePercent":0.62,"previousClose":517.30,"timestamp":"2026-03-01T16:00:00Z"}
        """.data(using: .utf8)!
        let data = try JSONDecoder.apiDecoder.decode(MarketQuote.self, from: json)
        XCTAssertEqual(data.symbol, "SPY")
        XCTAssertEqual(data.price, 520.50, accuracy: 0.01)
    }

    func testAIStrategyDecoding() throws {
        let json = """
        {"summary":"Shift 15% from cash to S&P 500 ETF","sentiment":"bullish","confidence":0.75,"top5reasons":[{"title":"Strong momentum","explanation":"S&P up 12% YTD","type":"bullish","confidence":"high"}],"allocation":{"stocks":60,"bonds":25,"cash":10,"alternatives":5}}
        """.data(using: .utf8)!
        let strategy = try JSONDecoder().decode(AIStrategy.self, from: json)
        XCTAssertEqual(strategy.sentiment, .bullish)
        XCTAssertEqual(strategy.top5reasons.count, 1)
        XCTAssertEqual(strategy.allocation.stocks, 60)
    }

    func testNewsItemDecoding() throws {
        let json = """
        {"title":"Fed holds rates steady","source":"Reuters","url":"https://example.com","publishedAt":"2026-03-01T10:00:00Z","description":"The Federal Reserve held rates."}
        """.data(using: .utf8)!
        let item = try JSONDecoder.apiDecoder.decode(NewsItem.self, from: json)
        XCTAssertEqual(item.title, "Fed holds rates steady")
    }

    func testPortfolioTotalValue() {
        let portfolio = Portfolio(ibkrBalance: 80_000, hsbcBalance: 40_000, allocation: AssetAllocation(stocks: 60, bonds: 25, cash: 10, alternatives: 5))
        XCTAssertEqual(portfolio.totalValue, 120_000, accuracy: 0.01)
    }
}
