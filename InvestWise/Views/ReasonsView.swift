import SwiftUI

struct ReasonsView: View {
    @EnvironmentObject var orchestrator: DataOrchestrator

    var body: some View {
        NavigationStack {
            Group {
                if let strategy = orchestrator.strategy {
                    reasonsList(strategy)
                } else {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "No Strategy Yet",
                            systemImage: "lightbulb.slash",
                            description: Text("Tap the button below to analyze current market data with AI.")
                        )
                        Button {
                            Task { await triggerAnalyze() }
                        } label: {
                            HStack {
                                if orchestrator.isAnalyzing {
                                    ProgressView().controlSize(.small)
                                }
                                Text(orchestrator.isAnalyzing ? "Analyzing..." : "Analyze with AI")
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(.teal, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                        }
                        .disabled(orchestrator.isAnalyzing)
                    }
                }
            }
            .navigationTitle("Top 5 Reasons")
            .refreshable { await triggerRefresh() }
        }
    }

    private func reasonsList(_ strategy: AIStrategy) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    SentimentBadge(sentiment: strategy.sentiment)
                    Spacer()
                    Text("Confidence: \(Int(strategy.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                ForEach(Array(strategy.top5reasons.enumerated()), id: \.offset) { index, reason in
                    reasonCard(index: index + 1, reason: reason)
                }
            }
            .padding()
        }
    }

    private func reasonCard(index: Int, reason: StrategyReason) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.title2.weight(.bold))
                .foregroundStyle(colorForType(reason.type))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reason.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(reason.confidence.rawValue.capitalized)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(confidenceColor(reason.confidence).opacity(0.2))
                        .foregroundStyle(confidenceColor(reason.confidence))
                        .clipShape(Capsule())
                }
                Text(reason.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func triggerRefresh() async {
        await withCheckedContinuation { continuation in
            Task {
                await orchestrator.refresh()
                continuation.resume()
            }
        }
    }

    private func triggerAnalyze() async {
        // Fetch data first if we have none, then analyze
        if orchestrator.quotes.isEmpty {
            await withCheckedContinuation { continuation in
                Task {
                    await orchestrator.refreshData()
                    continuation.resume()
                }
            }
        }
        await withCheckedContinuation { continuation in
            Task {
                await orchestrator.analyzeWithAI()
                continuation.resume()
            }
        }
    }

    private func colorForType(_ type: AIStrategy.Sentiment) -> Color {
        switch type {
        case .bullish: return .green
        case .bearish: return .red
        case .neutral: return .gray
        }
    }

    private func confidenceColor(_ confidence: StrategyReason.ReasonConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}
