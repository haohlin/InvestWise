import XCTest
@testable import InvestWise

final class MarketDataServiceTests: XCTestCase {
    func testParseYahooFinanceResponse() throws {
        let json = """
        {"chart":{"result":[{"meta":{"symbol":"SPY","regularMarketPrice":520.50,"previousClose":517.30,"chartPreviousClose":517.30},"timestamp":[1709251200,1709337600],"indicators":{"quote":[{"close":[515.20,520.50]}]}}]}}
        """.data(using: .utf8)!
        let quote = try MarketDataService.parseYahooQuote(symbol: "SPY", data: json)
        XCTAssertEqual(quote.symbol, "SPY")
        XCTAssertEqual(quote.price, 520.50, accuracy: 0.01)
        XCTAssertEqual(quote.previousClose, 517.30, accuracy: 0.01)
    }

    func testParseHistoricalPrices() throws {
        let json = """
        {"chart":{"result":[{"meta":{"symbol":"SPY"},"timestamp":[1709251200,1709337600],"indicators":{"quote":[{"close":[515.20,520.50]}]}}]}}
        """.data(using: .utf8)!
        let prices = try MarketDataService.parseHistoricalPrices(data: json)
        XCTAssertEqual(prices.count, 2)
        XCTAssertEqual(prices[1].close, 520.50, accuracy: 0.01)
    }
}
