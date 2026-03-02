import Foundation

final class MarketDataService {
    private let session: URLSession
    static let defaultSymbols = ["SPY", "QQQ", "^HSI", "GLD", "HKDUSD=X", "^TNX"]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchQuotes(symbols: [String] = defaultSymbols) async throws -> [MarketQuote] {
        try await withThrowingTaskGroup(of: MarketQuote?.self) { group in
            for symbol in symbols {
                group.addTask { [self] in
                    try? await fetchQuote(symbol: symbol)
                }
            }
            var quotes: [MarketQuote] = []
            for try await quote in group {
                if let quote { quotes.append(quote) }
            }
            return quotes
        }
    }

    func fetchQuote(symbol: String) async throws -> MarketQuote {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=1d")!
        let (data, _) = try await session.data(from: url)
        return try Self.parseYahooQuote(symbol: symbol, data: data)
    }

    func fetchHistorical(symbol: String, range: String = "1mo") async throws -> [HistoricalPrice] {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=\(range)&interval=1d")!
        let (data, _) = try await session.data(from: url)
        return try Self.parseHistoricalPrices(data: data)
    }

    static func parseYahooQuote(symbol: String, data: Data) throws -> MarketQuote {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let chart = json?["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let meta = result["meta"] as? [String: Any],
              let price = meta["regularMarketPrice"] as? Double,
              let previousClose = (meta["previousClose"] ?? meta["chartPreviousClose"]) as? Double
        else { throw MarketDataError.parseError }
        let change = price - previousClose
        let changePercent = (change / previousClose) * 100
        return MarketQuote(symbol: symbol, price: price, change: change, changePercent: changePercent, previousClose: previousClose, timestamp: Date())
    }

    static func parseHistoricalPrices(data: Data) throws -> [HistoricalPrice] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let chart = json?["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let timestamps = result["timestamp"] as? [Int],
              let indicators = result["indicators"] as? [String: Any],
              let quotes = indicators["quote"] as? [[String: Any]],
              let closes = quotes.first?["close"] as? [Double?]
        else { throw MarketDataError.parseError }
        return zip(timestamps, closes).compactMap { ts, close in
            guard let close else { return nil }
            return HistoricalPrice(date: Date(timeIntervalSince1970: TimeInterval(ts)), close: close, volume: nil)
        }
    }

    enum MarketDataError: Error { case parseError }
}
