import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var orchestrator: DataOrchestrator
    @State private var selectedProvider: AIProvider = .gemini
    @State private var aiKey = ""
    @State private var chipnemoEndpoint = ""
    @State private var chipnemoModel = ""
    @State private var newsKey = ""
    @State private var ibkrText = ""
    @State private var hsbcText = ""
    @State private var showSaved = false

    private let keychain = KeychainService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("AI Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    Text(providerFooter)
                }

                Section("AI API Key") {
                    SecureField(selectedProvider.keyPlaceholder, text: $aiKey)
                        .textContentType(.password)
                    if selectedProvider == .chipnemo {
                        TextField("Proxy endpoint URL", text: $chipnemoEndpoint)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                        TextField("Model name (e.g. claude-sonnet-4)", text: $chipnemoModel)
                            .autocapitalization(.none)
                    }
                    Button("Save AI Configuration") { saveAIConfig() }
                        .disabled(aiKey.isEmpty)
                }

                Section("News API Key (optional)") {
                    SecureField("NewsAPI key", text: $newsKey)
                        .textContentType(.password)
                    Button("Save News Key") { saveNewsKey() }
                        .disabled(newsKey.isEmpty)
                }

                Section("Portfolio Balances") {
                    HStack {
                        Text("IBKR ($)")
                        TextField("50000", text: $ibkrText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("HSBC HK ($)")
                        TextField("30000", text: $hsbcText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Button("Update Balances") { saveBalances() }
                }

                Section("Diagnostics") {
                    NavigationLink("AI Connectivity & Debug Log") {
                        DiagnosticsView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Data Sources", value: "Yahoo Finance, NewsAPI, Reddit")
                    LabeledContent("AI Provider", value: selectedProvider.displayName)
                }
            }
            .navigationTitle("Settings")
            .overlay(alignment: .bottom) {
                if showSaved {
                    Text("Saved")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.teal, in: Capsule())
                        .foregroundStyle(.white)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                }
            }
            .onAppear { loadSettings() }
            .onChange(of: selectedProvider) { _, newProvider in
                aiKey = keychain.retrieve(key: newProvider.keychainKey) ?? ""
            }
        }
    }

    private var providerFooter: String {
        switch selectedProvider {
        case .anthropic:
            return "Get your key at console.anthropic.com/settings/keys. Requires prepaid credits."
        case .chipnemo:
            return "Use your NVAuth token. Requires NVIDIA VPN. Endpoint auto-appends /chat/completions."
        case .gemini:
            return "Free tier available. Get your key at aistudio.google.com/apikey."
        }
    }

    private func loadSettings() {
        if let raw = UserDefaults.standard.string(forKey: AIProvider.providerDefaultsKey),
           let provider = AIProvider(rawValue: raw) {
            selectedProvider = provider
        }
        aiKey = keychain.retrieve(key: selectedProvider.keychainKey) ?? ""
        chipnemoEndpoint = UserDefaults.standard.string(forKey: AIProvider.chipnemoEndpointKey) ?? ""
        chipnemoModel = UserDefaults.standard.string(forKey: AIProvider.chipnemoModelKey) ?? ""
        newsKey = keychain.retrieve(key: "newsapi_key") ?? ""
        ibkrText = String(Int(orchestrator.ibkrBalance))
        hsbcText = String(Int(orchestrator.hsbcBalance))
    }

    private func saveAIConfig() {
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: AIProvider.providerDefaultsKey)
        keychain.save(key: selectedProvider.keychainKey, value: aiKey)
        if selectedProvider == .chipnemo {
            if !chipnemoEndpoint.isEmpty {
                UserDefaults.standard.set(chipnemoEndpoint, forKey: AIProvider.chipnemoEndpointKey)
            }
            if !chipnemoModel.isEmpty {
                UserDefaults.standard.set(chipnemoModel, forKey: AIProvider.chipnemoModelKey)
            }
        }
        flashSaved()
    }

    private func saveNewsKey() {
        keychain.save(key: "newsapi_key", value: newsKey)
        flashSaved()
    }

    private func saveBalances() {
        if let ibkr = Double(ibkrText) { orchestrator.ibkrBalance = ibkr }
        if let hsbc = Double(hsbcText) { orchestrator.hsbcBalance = hsbc }
        flashSaved()
    }

    private func flashSaved() {
        withAnimation { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSaved = false }
        }
    }
}
