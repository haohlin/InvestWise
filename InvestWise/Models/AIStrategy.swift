import Foundation

struct AIStrategy: Codable {
    let summary: String
    let sentiment: Sentiment
    let confidence: Double
    let reasons: [StrategyReason]
    let allocation: AssetAllocation
    enum Sentiment: String, Codable { case bullish, bearish, neutral }

    private enum CodingKeys: String, CodingKey {
        case summary, sentiment, confidence, reasons, top5reasons, allocation
    }

    init(summary: String, sentiment: Sentiment, confidence: Double, reasons: [StrategyReason], allocation: AssetAllocation) {
        self.summary = summary
        self.sentiment = sentiment
        self.confidence = confidence
        self.reasons = reasons
        self.allocation = allocation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        sentiment = try container.decode(Sentiment.self, forKey: .sentiment)
        confidence = try container.decode(Double.self, forKey: .confidence)
        allocation = try container.decode(AssetAllocation.self, forKey: .allocation)
        // Accept both "reasons" and legacy "top5reasons"
        if let r = try? container.decode([StrategyReason].self, forKey: .reasons) {
            reasons = r
        } else {
            reasons = try container.decode([StrategyReason].self, forKey: .top5reasons)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(summary, forKey: .summary)
        try container.encode(sentiment, forKey: .sentiment)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(reasons, forKey: .reasons)
        try container.encode(allocation, forKey: .allocation)
    }
}

struct StrategyReason: Codable, Identifiable {
    var id: String { title }
    let title: String
    let explanation: String
    let type: AIStrategy.Sentiment
    let confidence: ReasonConfidence
    let sources: [String]
    enum ReasonConfidence: String, Codable { case high, medium, low }

    private enum CodingKeys: String, CodingKey {
        case title, explanation, type, confidence, sources
    }

    init(title: String, explanation: String, type: AIStrategy.Sentiment, confidence: ReasonConfidence, sources: [String] = []) {
        self.title = title
        self.explanation = explanation
        self.type = type
        self.confidence = confidence
        self.sources = sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        explanation = try container.decode(String.self, forKey: .explanation)
        type = try container.decode(AIStrategy.Sentiment.self, forKey: .type)
        confidence = try container.decode(ReasonConfidence.self, forKey: .confidence)
        sources = (try? container.decode([String].self, forKey: .sources)) ?? []
    }
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
