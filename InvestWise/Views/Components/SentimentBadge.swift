import SwiftUI

struct SentimentBadge: View {
    let sentiment: AIStrategy.Sentiment

    var body: some View {
        Text(sentiment.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch sentiment {
        case .bullish: return .green
        case .bearish: return .red
        case .neutral: return .gray
        }
    }
}

struct NewsSentimentBadge: View {
    let tag: NewsItem.SentimentTag

    var body: some View {
        Text(tag.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch tag {
        case .bullish: return .green
        case .bearish: return .red
        case .neutral: return .gray
        }
    }
}
