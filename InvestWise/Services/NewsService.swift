import Foundation

final class NewsService {
    private let session: URLSession
    private let apiKey: () -> String?

    init(session: URLSession = .shared, apiKey: @escaping () -> String? = { nil }) {
        self.session = session
        self.apiKey = apiKey
    }

    func fetchNews(query: String = "stock market investment") async throws -> [NewsItem] {
        if let key = apiKey(), !key.isEmpty {
            let items = try await fetchNewsAPI(query: query, key: key)
            if !items.isEmpty { return items }
        }
        // Fallback: try multiple RSS sources
        return try await fetchRSSNews()
    }

    private func fetchNewsAPI(query: String, key: String) async throws -> [NewsItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://newsapi.org/v2/everything?q=\(encoded)&language=en&sortBy=publishedAt&pageSize=20&apiKey=\(key)")!
        let (data, _) = try await session.data(from: url)
        return try Self.parseNewsAPIResponse(data: data)
    }

    /// Try multiple RSS feeds until one works
    func fetchRSSNews() async throws -> [NewsItem] {
        let feeds: [(url: String, source: String)] = [
            ("https://finance.yahoo.com/news/rssindex", "Yahoo Finance"),
            ("https://feeds.content.dowjones.io/public/rss/mw_topstories", "MarketWatch"),
            ("https://feeds.bbci.co.uk/news/business/rss.xml", "BBC Business"),
        ]
        for feed in feeds {
            if let items = try? await fetchSingleRSS(feedURL: feed.url, fallbackSource: feed.source), !items.isEmpty {
                return items
            }
        }
        return []
    }

    private func fetchSingleRSS(feedURL: String, fallbackSource: String) async throws -> [NewsItem] {
        guard let url = URL(string: feedURL) else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await session.data(for: request)

        // Try rss2json first (works for some feeds)
        let rss2jsonURL = "https://api.rss2json.com/v1/api.json?rss_url=\(feedURL)&count=15"
        if let rssURL = URL(string: rss2jsonURL) {
            if let (jsonData, _) = try? await session.data(from: rssURL) {
                let items = try Self.parseRSSJSONResponse(data: jsonData, fallbackSource: fallbackSource)
                if !items.isEmpty { return items }
            }
        }

        // Parse raw XML RSS as fallback
        return Self.parseRawRSS(data: data, fallbackSource: fallbackSource)
    }

    // MARK: - Parsers

    static func parseNewsAPIResponse(data: Data) throws -> [NewsItem] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let articles = json?["articles"] as? [[String: Any]] else { return [] }
        let formatter = ISO8601DateFormatter()
        return articles.compactMap { article in
            guard let title = article["title"] as? String,
                  let source = (article["source"] as? [String: Any])?["name"] as? String,
                  let url = article["url"] as? String,
                  let dateStr = article["publishedAt"] as? String,
                  let date = formatter.date(from: dateStr)
            else { return nil }
            let description = article["description"] as? String
            return NewsItem(title: title, source: source, url: url, publishedAt: date, description: description)
        }
    }

    static func parseRSSJSONResponse(data: Data, fallbackSource: String = "RSS") throws -> [NewsItem] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let items = json?["items"] as? [[String: Any]] else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return items.compactMap { item in
            guard let title = item["title"] as? String,
                  let url = item["link"] as? String,
                  let dateStr = item["pubDate"] as? String
            else { return nil }
            let date = formatter.date(from: dateStr) ?? fallbackFormatter.date(from: dateStr) ?? Date()
            let description = item["description"] as? String
            let source = (item["author"] as? String) ?? fallbackSource
            return NewsItem(title: title, source: source, url: url, publishedAt: date, description: description)
        }
    }

    /// Minimal XML RSS parser for <item> elements
    static func parseRawRSS(data: Data, fallbackSource: String) -> [NewsItem] {
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        var items: [NewsItem] = []
        let itemBlocks = xml.components(separatedBy: "<item>").dropFirst()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        for block in itemBlocks.prefix(15) {
            guard let title = extractTag("title", from: block),
                  let link = extractTag("link", from: block)
            else { continue }
            let pubDate = extractTag("pubDate", from: block)
            let date = pubDate.flatMap { dateFormatter.date(from: $0) } ?? Date()
            let desc = extractTag("description", from: block)
            items.append(NewsItem(title: title, source: fallbackSource, url: link, publishedAt: date, description: desc))
        }
        return items
    }

    private static func extractTag(_ tag: String, from xml: String) -> String? {
        // Handle both <tag>content</tag> and <tag><![CDATA[content]]></tag>
        guard let startRange = xml.range(of: "<\(tag)>") ?? xml.range(of: "<\(tag) ") else { return nil }
        let afterStart: String
        if let gtRange = xml[startRange.upperBound...].range(of: ">") {
            afterStart = String(xml[gtRange.upperBound...])
        } else {
            afterStart = String(xml[startRange.upperBound...])
        }
        guard let endRange = afterStart.range(of: "</\(tag)>") else { return nil }
        var content = String(afterStart[..<endRange.lowerBound])
        // Strip CDATA wrapper
        if content.hasPrefix("<![CDATA[") {
            content = content
                .replacingOccurrences(of: "<![CDATA[", with: "")
                .replacingOccurrences(of: "]]>", with: "")
        }
        // Strip HTML tags
        content = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
