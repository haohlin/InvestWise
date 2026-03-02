import SwiftUI

private struct BottomOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

struct DashboardView: View {
    @EnvironmentObject var orchestrator: DataOrchestrator
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    marketStrip
                    aiSection
                    sentimentSection
                    newsSection

                    if orchestrator.canLoadMore {
                        loadMoreIndicator
                    }
                }
                .padding()
            }
            .coordinateSpace(name: "scroll")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in viewportHeight = h }
                }
            )
            .onPreferenceChange(BottomOffsetKey.self) { maxY in
                guard viewportHeight > 0 else { return }
                let overscroll = viewportHeight - maxY
                if overscroll > 40, !orchestrator.isLoadingMore, orchestrator.canLoadMore {
                    Task { await orchestrator.loadMore() }
                }
            }
            .navigationTitle("Dashboard")
            .refreshable { await triggerRefresh() }
            .overlay {
                if orchestrator.isLoading && orchestrator.quotes.isEmpty {
                    LoadingOverlay(message: "Fetching market data...")
                }
            }
            .task { if orchestrator.quotes.isEmpty { await orchestrator.refreshData() } }
        }
    }

    // MARK: - Market strip

    private var marketStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(orchestrator.quotes) { quote in
                    QuoteCard(quote: quote)
                }
            }
        }
    }

    // MARK: - AI Strategy section (with analyze button)

    @ViewBuilder
    private var aiSection: some View {
        if let strategy = orchestrator.strategy {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("AI Strategy")
                        .font(.headline)
                    Spacer()
                    SentimentBadge(sentiment: strategy.sentiment)
                }
                Text(strategy.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                AllocationChart(allocation: strategy.allocation)

                analyzeButton
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundStyle(.teal)
                Text("Tap to generate AI investment strategy")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                analyzeButton
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var analyzeButton: some View {
        Button {
            Task { await triggerAnalyze() }
        } label: {
            HStack {
                if orchestrator.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(orchestrator.isAnalyzing ? "Analyzing..." : "Analyze with AI")
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.teal.opacity(orchestrator.isAnalyzing ? 0.3 : 1), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
        }
        .disabled(orchestrator.isAnalyzing)
    }

    // MARK: - Sentiment gauge

    private var sentimentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Market Sentiment")
                    .font(.headline)
                Spacer()
                SentimentBadge(sentiment: orchestrator.sentimentLabel)
            }
            Gauge(value: (orchestrator.sentimentScore + 1) / 2) {
                EmptyView()
            } currentValueLabel: {
                Text(String(format: "%.0f%%", (orchestrator.sentimentScore + 1) / 2 * 100))
                    .font(.caption)
            } minimumValueLabel: {
                Text("Bear").font(.caption2).foregroundStyle(.red)
            } maximumValueLabel: {
                Text("Bull").font(.caption2).foregroundStyle(.green)
            }
            .tint(Gradient(colors: [.red, .orange, .green]))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - News + Reddit combined feed

    @ViewBuilder
    private var newsSection: some View {
        let hasNews = !orchestrator.news.isEmpty
        let hasReddit = !orchestrator.redditPosts.isEmpty
        if hasNews || hasReddit {
            VStack(alignment: .leading, spacing: 10) {
                Text("Latest News & Discussions")
                    .font(.headline)
                ForEach(orchestrator.news) { item in
                    newsRow(item)
                }
                if hasReddit {
                    if hasNews {
                        Divider()
                        Text("Trending on Reddit")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    ForEach(orchestrator.redditPosts, id: \.permalink) { post in
                        redditRow(post)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Load more (pull-up)

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
        .padding(.vertical, 16)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: BottomOffsetKey.self,
                    value: geo.frame(in: .named("scroll")).maxY
                )
            }
        )
    }

    // MARK: - Helpers

    /// Detach into unstructured Task so SwiftUI's refreshable cancellation
    /// doesn't abort network requests when the user lifts their finger.
    private func triggerRefresh() async {
        await withCheckedContinuation { continuation in
            Task {
                await orchestrator.refreshData()
                continuation.resume()
            }
        }
    }

    private func triggerAnalyze() async {
        await withCheckedContinuation { continuation in
            Task {
                await orchestrator.analyzeWithAI()
                continuation.resume()
            }
        }
    }

    private func newsRow(_ item: NewsItem) -> some View {
        Link(destination: URL(string: item.url) ?? URL(string: "https://")!) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.source)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.teal)
                    Spacer()
                    NewsSentimentBadge(tag: item.sentimentTag)
                }
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(item.publishedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
