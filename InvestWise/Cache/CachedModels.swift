import Foundation
import SwiftData

@Model
final class CachedStrategy {
    var summary: String
    var sentiment: String
    var confidence: Double
    var reasonsJSON: Data
    var allocationJSON: Data
    var cachedAt: Date

    init(from strategy: AIStrategy) throws {
        self.summary = strategy.summary
        self.sentiment = strategy.sentiment.rawValue
        self.confidence = strategy.confidence
        self.reasonsJSON = try JSONEncoder().encode(strategy.top5reasons)
        self.allocationJSON = try JSONEncoder().encode(strategy.allocation)
        self.cachedAt = Date()
    }

    func toStrategy() throws -> AIStrategy {
        let reasons = try JSONDecoder().decode([StrategyReason].self, from: reasonsJSON)
        let allocation = try JSONDecoder().decode(AssetAllocation.self, from: allocationJSON)
        return AIStrategy(summary: summary, sentiment: AIStrategy.Sentiment(rawValue: sentiment) ?? .neutral, confidence: confidence, top5reasons: reasons, allocation: allocation)
    }
}

@Model
final class CachedMarketQuote {
    var symbol: String
    var price: Double
    var change: Double
    var changePercent: Double
    var previousClose: Double
    var cachedAt: Date

    init(from quote: MarketQuote) {
        self.symbol = quote.symbol
        self.price = quote.price
        self.change = quote.change
        self.changePercent = quote.changePercent
        self.previousClose = quote.previousClose
        self.cachedAt = Date()
    }

    func toQuote() -> MarketQuote {
        MarketQuote(symbol: symbol, price: price, change: change, changePercent: changePercent, previousClose: previousClose, timestamp: cachedAt)
    }
}

@Model
final class CachedNewsItem {
    var title: String
    var source: String
    var url: String
    var publishedAt: Date
    var itemDescription: String?
    var sentimentTag: String
    var cachedAt: Date

    init(from item: NewsItem) {
        self.title = item.title
        self.source = item.source
        self.url = item.url
        self.publishedAt = item.publishedAt
        self.itemDescription = item.description
        self.sentimentTag = item.sentimentTag.rawValue
        self.cachedAt = Date()
    }

    func toNewsItem() -> NewsItem {
        NewsItem(title: title, source: source, url: url, publishedAt: publishedAt, description: itemDescription, sentimentTag: NewsItem.SentimentTag(rawValue: sentimentTag) ?? .neutral)
    }
}
