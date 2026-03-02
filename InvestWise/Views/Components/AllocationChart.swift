import SwiftUI

struct AllocationChart: View {
    let allocation: AssetAllocation

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(segments, id: \.label) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(0, geo.size.width * CGFloat(segment.value) / 100))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 24)

            HStack(spacing: 16) {
                ForEach(segments, id: \.label) { segment in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 8, height: 8)
                        Text("\(segment.label) \(segment.value)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var segments: [(label: String, value: Int, color: Color)] {
        [
            ("Stocks", allocation.stocks, .teal),
            ("Bonds", allocation.bonds, .blue),
            ("Cash", allocation.cash, .orange),
            ("Alt", allocation.alternatives, .purple)
        ]
    }
}
