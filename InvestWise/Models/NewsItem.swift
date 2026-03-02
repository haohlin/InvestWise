import Foundation

struct NewsItem: Codable, Identifiable {
    var id: String { url }
    let title: String
    let source: String
    let url: String
    let publishedAt: Date
    let description: String?
    var sentimentTag: SentimentTag = .neutral

    enum SentimentTag: String, Codable {
        case bullish = "Bullish"
        case bearish = "Bearish"
        case neutral = "Neutral"
    }

    enum CodingKeys: String, CodingKey {
        case title, source, url, publishedAt, description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        source = try container.decode(String.self, forKey: .source)
        url = try container.decode(String.self, forKey: .url)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        sentimentTag = .neutral
    }

    init(title: String, source: String, url: String, publishedAt: Date, description: String?, sentimentTag: SentimentTag = .neutral) {
        self.title = title
        self.source = source
        self.url = url
        self.publishedAt = publishedAt
        self.description = description
        self.sentimentTag = sentimentTag
    }
}
