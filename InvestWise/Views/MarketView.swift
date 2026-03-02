import SwiftUI

struct MarketView: View {
    @EnvironmentObject var orchestrator: DataOrchestrator

    var body: some View {
        NavigationStack {
            List {
                Section("Tracked Indices & Assets") {
                    ForEach(orchestrator.quotes) { quote in
                        quoteRow(quote)
                    }
                }

                if !orchestrator.redditPosts.isEmpty {
                    Section("Reddit Trending") {
                        ForEach(orchestrator.redditPosts.prefix(10), id: \.permalink) { post in
                            redditRow(post)
                        }
                    }
                }
            }
            .navigationTitle("Market")
            .refreshable {
                await withCheckedContinuation { continuation in
                    Task {
                        await orchestrator.refreshData()
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func quoteRow(_ quote: MarketQuote) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(quote.symbol)
                    .font(.subheadline.weight(.semibold))
                Text(formattedPrice(quote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(changeString(quote))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(quote.isPositive ? .green : .red)
                Text(percentString(quote))
                    .font(.caption)
                    .foregroundStyle(quote.isPositive ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }

    private func redditRow(_ post: RedditPost) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.title)
                .font(.subheadline)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label("\(post.score)", systemImage: "arrow.up")
                Label("\(post.numComments)", systemImage: "bubble.right")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formattedPrice(_ q: MarketQuote) -> String {
        q.price < 1 ? String(format: "%.4f", q.price) : String(format: "%.2f", q.price)
    }

    private func changeString(_ q: MarketQuote) -> String {
        let sign = q.isPositive ? "+" : ""
        return "\(sign)\(String(format: "%.2f", q.change))"
    }

    private func percentString(_ q: MarketQuote) -> String {
        let sign = q.isPositive ? "+" : ""
        return "\(sign)\(String(format: "%.2f", q.changePercent))%"
    }
}
