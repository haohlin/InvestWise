import Foundation
import SwiftData

@MainActor
final class CacheManager {
    private let container: ModelContainer

    init() throws {
        let schema = Schema([CachedStrategy.self, CachedMarketQuote.self, CachedNewsItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.container = try ModelContainer(for: schema, configurations: [config])
    }

    var context: ModelContext { container.mainContext }

    func cacheStrategy(_ strategy: AIStrategy) throws {
        let descriptor = FetchDescriptor<CachedStrategy>()
        let existing = try context.fetch(descriptor)
        existing.forEach { context.delete($0) }
        let cached = try CachedStrategy(from: strategy)
        context.insert(cached)
        try context.save()
    }

    func loadCachedStrategy() throws -> AIStrategy? {
        let descriptor = FetchDescriptor<CachedStrategy>(sortBy: [SortDescriptor(\.cachedAt, order: .reverse)])
        guard let cached = try context.fetch(descriptor).first else { return nil }
        return try cached.toStrategy()
    }

    func cacheMarketQuotes(_ quotes: [MarketQuote]) throws {
        let descriptor = FetchDescriptor<CachedMarketQuote>()
        let existing = try context.fetch(descriptor)
        existing.forEach { context.delete($0) }
        for quote in quotes { context.insert(CachedMarketQuote(from: quote)) }
        try context.save()
    }

    func loadCachedQuotes() throws -> [MarketQuote] {
        let descriptor = FetchDescriptor<CachedMarketQuote>()
        return try context.fetch(descriptor).map { $0.toQuote() }
    }

    func cacheNews(_ items: [NewsItem]) throws {
        let descriptor = FetchDescriptor<CachedNewsItem>()
        let existing = try context.fetch(descriptor)
        existing.forEach { context.delete($0) }
        for item in items { context.insert(CachedNewsItem(from: item)) }
        try context.save()
    }

    func loadCachedNews() throws -> [NewsItem] {
        let descriptor = FetchDescriptor<CachedNewsItem>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        return try context.fetch(descriptor).map { $0.toNewsItem() }
    }
}
