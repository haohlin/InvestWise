import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var orchestrator: DataOrchestrator
    @State private var testResult: String?
    @State private var isTesting = false

    private var aiService: AIService { orchestrator.aiService }
    private var provider: AIProvider { aiService.currentProvider }

    var body: some View {
        List {
            Section("AI Provider Status") {
                LabeledContent("Provider", value: provider.displayName)
                LabeledContent("Key configured") {
                    Image(systemName: aiService.hasKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(aiService.hasKey ? .green : .red)
                }
                Button {
                    Task { await runTest() }
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isTesting || !aiService.hasKey)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("reachable") ? .green : .red)
                        .textSelection(.enabled)
                }
            }

            if provider == .gemini {
                Section("Gemini Rate Limits") {
                    if let modelName = orchestrator.lastGeminiModel {
                        LabeledContent("Active model", value: modelName)
                    }

                    let router = GeminiModelRouter.shared
                    let rateLimiter = GeminiRateLimiter.shared

                    if router.shouldCompactPrompt() {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Compact mode active — conserving quota")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    ForEach(GeminiModel.byQuality, id: \.rawValue) { model in
                        let used = rateLimiter.dailyRequestCount(for: model)
                        let available = rateLimiter.canUse(model)
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(available ? .green : .red)
                            Text(model.displayName)
                                .font(.caption)
                            Spacer()
                            Text("\(used) / \(model.rpd)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(dailyUsageColor(used: used, limit: model.rpd))
                        }
                    }
                }
            }

            Section("Data Status") {
                LabeledContent("Market quotes", value: "\(orchestrator.quotes.count)")
                LabeledContent("News articles", value: "\(orchestrator.news.count)")
                LabeledContent("Reddit posts", value: "\(orchestrator.redditPosts.count)")
                LabeledContent("AI Strategy") {
                    Image(systemName: orchestrator.strategy != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(orchestrator.strategy != nil ? .green : .orange)
                }
            }

            if let error = orchestrator.error {
                Section("Current Error") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("Activity Log") {
                if orchestrator.diagnosticLogs.isEmpty {
                    Text("No activity yet. Pull to refresh on Dashboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orchestrator.diagnosticLogs) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(log.source)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(log.isError ? .red : .teal)
                                Spacer()
                                Text(log.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(log.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Diagnostics")
    }

    private func dailyUsageColor(used: Int, limit: Int) -> Color {
        let ratio = Double(used) / Double(limit)
        if ratio >= 0.9 { return .red }
        if ratio >= 0.75 { return .orange }
        return .green
    }

    private func runTest() async {
        isTesting = true
        testResult = nil
        orchestrator.log("Test", "Testing \(provider.displayName) connection...")
        let result = await aiService.testConnection()
        testResult = result.message
        orchestrator.log("Test", result.success ? "Success" : "Failed: \(result.message)", isError: !result.success)
        isTesting = false
    }
}
