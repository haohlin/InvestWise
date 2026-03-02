import SwiftUI

struct QuoteCard: View {
    let quote: MarketQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(quote.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(formattedPrice)
                .font(.system(.title3, design: .rounded, weight: .bold))
            HStack(spacing: 4) {
                Image(systemName: quote.isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(formattedChange)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(quote.isPositive ? .green : .red)
        }
        .padding(12)
        .frame(minWidth: 110, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var formattedPrice: String {
        if quote.price < 1 {
            return String(format: "%.4f", quote.price)
        }
        return String(format: "%.2f", quote.price)
    }

    private var formattedChange: String {
        let sign = quote.isPositive ? "+" : ""
        return "\(sign)\(String(format: "%.2f", quote.changePercent))%"
    }
}
