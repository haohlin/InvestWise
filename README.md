# InvestWise

**AI-powered investment strategy advisor in your pocket.**

InvestWise pulls live market data, trending news, and Reddit sentiment — then runs it all through an AI model to generate a personalized, actionable investment strategy with portfolio allocation recommendations.

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue?logo=apple)
![License](https://img.shields.io/badge/License-MIT-green)
![AI Models](https://img.shields.io/badge/AI-Gemini%20%7C%20Claude%20%7C%20ChipNemo-purple)

---

## What It Does

| Feature | Details |
|---|---|
| **Live Market Data** | Real-time quotes for SPY, QQQ, HSI, Gold, HKD/USD, 10Y Treasury via Yahoo Finance |
| **News Aggregation** | NewsAPI + RSS fallback (Yahoo Finance, MarketWatch, BBC Business) |
| **Reddit Sentiment** | Trending posts from r/investing and r/stocks, scored by engagement |
| **AI Strategy Engine** | Multi-provider support: Google Gemini (free tier), Anthropic Claude, NVIDIA ChipNemo |
| **Smart Model Fallback** | Automatically cycles through 5 Gemini models when rate-limited — zero manual intervention |
| **Portfolio Tracking** | Dual-account view (IBKR + HSBC) with dynamic allocation charts |
| **Sentiment Analysis** | Keyword-based scoring across news and Reddit, weighted by engagement |
| **Offline Support** | SwiftData caching — last strategy and market data available offline |

## Smart Rate Limiting

InvestWise includes a built-in rate limit tracker that makes the Gemini free tier actually usable:

```
gemini-2.5-flash  →  gemini-3-flash  →  gemini-2.5-flash-lite  →  gemma-3-27b  →  gemma-3-12b
       ↑                                                                                  ↑
  Best quality                                                              Highest quota
```

- Tracks RPM (requests/minute) and RPD (requests/day) per model
- Automatically falls back to the next available model on 429 errors
- Compacts prompts when daily quota runs low (fewer news/Reddit items)
- Full visibility in the Diagnostics panel — see exactly which model served each response

## Quick Start

### Prerequisites

- Xcode 15+ with iOS 17 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A free [Gemini API key](https://aistudio.google.com/apikey) (or Anthropic/ChipNemo key)

### Build & Run

```bash
git clone https://github.com/haohlin/InvestWise.git
cd InvestWise
xcodegen generate
open InvestWise.xcodeproj
```

1. Build and run on a simulator or device
2. Go to **Settings** → paste your Gemini API key
3. Pull to refresh on the **Dashboard**, then tap **Analyze with AI**
4. Check **Diagnostics** to see rate limit status and which model was used

## Architecture

```
InvestWise/
├── Models/          # AIStrategy, MarketQuote, NewsItem, Portfolio
├── Services/
│   ├── ClaudeAIService.swift       # Multi-provider AI with fallback
│   ├── GeminiRateLimiter.swift     # Per-model RPM/RPD tracking
│   ├── GeminiModelRouter.swift     # Quality-ordered fallback chain
│   ├── DataOrchestrator.swift      # Central coordinator
│   ├── MarketDataService.swift     # Yahoo Finance client
│   ├── NewsService.swift           # NewsAPI + RSS fallback
│   ├── RedditService.swift         # Reddit hot posts
│   └── SentimentService.swift      # Keyword sentiment scoring
├── Views/           # SwiftUI views (Dashboard, Portfolio, Market, Settings, Diagnostics)
├── Cache/           # SwiftData persistence
└── ViewModels/      # App state management
```

## AI Providers

| Provider | Model | Cost | Setup |
|---|---|---|---|
| **Gemini** (default) | Auto-selects from 5 models | Free tier | Get key from [AI Studio](https://aistudio.google.com/apikey) |
| **Anthropic** | Claude Sonnet 4.6 | Pay-per-use | Get key from [Anthropic Console](https://console.anthropic.com/) |
| **ChipNemo** | Claude via NVIDIA proxy | Internal | NVIDIA employees only |

## Testing

```bash
xcodegen generate
xcodebuild test -scheme InvestWise -destination 'platform=iOS Simulator,name=iPhone 17'
```

Tests cover: prompt construction, JSON parsing, rate limiter tracking, model router selection, and compact prompt generation.

## License

MIT License. See [LICENSE](LICENSE) for details.

---

*Built with SwiftUI, SwiftData, and a healthy dose of AI.*
