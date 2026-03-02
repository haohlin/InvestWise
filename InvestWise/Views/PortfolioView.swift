import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var orchestrator: DataOrchestrator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    totalValueCard
                    accountBreakdown
                    if let alloc = orchestrator.strategy?.allocation {
                        allocationSection(alloc)
                    }
                }
                .padding()
            }
            .navigationTitle("Portfolio")
        }
    }

    private var totalValueCard: some View {
        VStack(spacing: 8) {
            Text("Total Portfolio Value")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("$\(Int(orchestrator.portfolio.totalValue))")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.teal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var accountBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)
            accountRow(name: "IBKR", balance: orchestrator.ibkrBalance, percent: orchestrator.portfolio.ibkrPercentage, color: .teal)
            accountRow(name: "HSBC HK", balance: orchestrator.hsbcBalance, percent: orchestrator.portfolio.hsbcPercentage, color: .blue)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func accountRow(name: String, balance: Double, percent: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline.weight(.medium))
            Spacer()
            VStack(alignment: .trailing) {
                Text("$\(Int(balance))")
                    .font(.subheadline.weight(.semibold))
                Text("\(Int(percent))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func allocationSection(_ allocation: AssetAllocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Allocation")
                .font(.headline)
            AllocationChart(allocation: allocation)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
