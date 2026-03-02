import SwiftUI

private struct MarketBottomOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

struct MarketView: View {
    @EnvironmentObject var orchestrator: DataOrchestrator
    @State private var viewportHeight: CGFloat = 0

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
                        ForEach(orchestrator.redditPosts, id: \.permalink) { post in
                            redditRow(post)
                        }
                    }
                }

                if orchestrator.canLoadMore {
                    Section {
                        loadMoreIndicator
                    }
                }
            }
            .coordinateSpace(name: "list")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in viewportHeight = h }
                }
            )
            .onPreferenceChange(MarketBottomOffsetKey.self) { maxY in
                guard viewportHeight > 0 else { return }
                let overscroll = viewportHeight - maxY
                if overscroll > 40, !orchestrator.isLoadingMore, orchestrator.canLoadMore {
                    Task { await orchestrator.loadMore() }
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

    private var loadMoreIndicator: some View {
        VStack(spacing: 4) {
            if orchestrator.isLoadingMore {
                ProgressView()
                    .controlSize(.small)
                Text("Loading\u{2026}")
                    .font(.caption2)
            } else {
                Image(systemName: "arrow.up")
                    .imageScale(.small)
                Text("Pull up for more")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MarketBottomOffsetKey.self,
                    value: geo.frame(in: .named("list")).maxY
                )
            }
        )
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
        Link(destination: URL(string: "https://www.reddit.com" + post.permalink)!) {
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Label("\(post.score)", systemImage: "arrow.up")
                    Label("\(post.numComments)", systemImage: "bubble.right")
                    Text("r/\(post.subreddit)")
                        .foregroundStyle(.orange)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
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
