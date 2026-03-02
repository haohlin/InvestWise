import Foundation

struct Portfolio {
    let ibkrBalance: Double
    let hsbcBalance: Double
    let allocation: AssetAllocation
    var totalValue: Double { ibkrBalance + hsbcBalance }
    var ibkrPercentage: Double { ibkrBalance / totalValue * 100 }
    var hsbcPercentage: Double { hsbcBalance / totalValue * 100 }
}
