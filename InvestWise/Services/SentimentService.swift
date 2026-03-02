import Foundation

final class SentimentService {
    private static let bullishWords = Set(["surge", "rally", "gain", "bull", "growth", "record", "high", "beat", "strong", "up", "rise", "profit", "boom", "optimis"])
    private static let bearishWords = Set(["crash", "fall", "drop", "bear", "recession", "low", "loss", "miss", "weak", "down", "decline", "fear", "sell", "pessimis"])

    static func tagSentiment(_ text: String) -> NewsItem.SentimentTag {
        let lower = text.lowercased()
        let words = lower.split(separator: " ").map(String.init)
        var bullScore = 0
        var bearScore = 0
        for word in words {
            if bullishWords.contains(where: { word.contains($0) }) { bullScore += 1 }
            if bearishWords.contains(where: { word.contains($0) }) { bearScore += 1 }
        }
        if bullScore > bearScore { return .bullish }
        if bearScore > bullScore { return .bearish }
        return .neutral
    }

    static func aggregateSentiment(news: [NewsItem], redditPosts: [RedditPost]) -> (score: Double, label: AIStrategy.Sentiment) {
        var total = 0.0
        var count = 0.0
        for item in news {
            let tag = tagSentiment(item.title + " " + (item.description ?? ""))
            switch tag {
            case .bullish: total += 1.0
            case .bearish: total -= 1.0
            case .neutral: break
            }
            count += 1
        }
        for post in redditPosts {
            let tag = tagSentiment(post.title + " " + post.selftext)
            let weight = min(Double(post.score) / 500.0, 2.0)
            switch tag {
            case .bullish: total += weight
            case .bearish: total -= weight
            case .neutral: break
            }
            count += 1
        }
        let score = count > 0 ? total / count : 0
        let label: AIStrategy.Sentiment = score > 0.1 ? .bullish : (score < -0.1 ? .bearish : .neutral)
        return (score: max(-1, min(1, score)), label: label)
    }
}
