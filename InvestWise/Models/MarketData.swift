import Foundation

struct MarketQuote: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let previousClose: Double
    let timestamp: Date
    var isPositive: Bool { change >= 0 }
}

struct HistoricalPrice: Codable {
    let date: Date
    let close: Double
    let volume: Int?
}

struct MarketSnapshot {
    let quotes: [MarketQuote]
    let historicalPrices: [String: [HistoricalPrice]]
    let fetchedAt: Date
}

extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
