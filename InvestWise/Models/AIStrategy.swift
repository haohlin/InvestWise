import Foundation

struct AIStrategy: Codable {
    let summary: String
    let sentiment: Sentiment
    let confidence: Double
    let top5reasons: [StrategyReason]
    let allocation: AssetAllocation
    enum Sentiment: String, Codable { case bullish, bearish, neutral }
}

struct StrategyReason: Codable, Identifiable {
    var id: String { title }
    let title: String
    let explanation: String
    let type: AIStrategy.Sentiment
    let confidence: ReasonConfidence
    enum ReasonConfidence: String, Codable { case high, medium, low }
}

struct AssetAllocation: Codable {
    let stocks: Int
    let bonds: Int
    let cash: Int
    let alternatives: Int

    private enum CodingKeys: String, CodingKey {
        case stocks, bonds, cash, alternatives
    }

    // LLMs sometimes return allocation values as floats (e.g. 65.0 instead of 65)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stocks = try Self.decodeInt(from: container, key: .stocks)
        bonds = try Self.decodeInt(from: container, key: .bonds)
        cash = try Self.decodeInt(from: container, key: .cash)
        alternatives = try Self.decodeInt(from: container, key: .alternatives)
    }

    init(stocks: Int, bonds: Int, cash: Int, alternatives: Int) {
        self.stocks = stocks
        self.bonds = bonds
        self.cash = cash
        self.alternatives = alternatives
    }

    private static func decodeInt(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Int {
        if let intVal = try? container.decode(Int.self, forKey: key) {
            return intVal
        }
        let doubleVal = try container.decode(Double.self, forKey: key)
        return Int(doubleVal)
    }
}
