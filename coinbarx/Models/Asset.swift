import Foundation

/// A tracked token, identified by its Solana SPL mint address (Jupiter's price id).
struct Asset: Identifiable, Hashable {
    let mint: String
    let label: String

    var id: String { mint }
}

extension Asset {
    /// Tracked tokens. Append one line to add a token; the first is the menu bar's primary.
    static let tracked: [Asset] = [
        Asset(mint: "So11111111111111111111111111111111111111112", label: "SOL"),
    ]
}

/// Latest price and 24h change for an asset.
struct Quote {
    let lastPrice: Double
    let priceChangePercent: Double
}

/// A buy position: `costUSDC` paid to receive `quantity` of the primary asset (SOL).
/// P&L is computed live against the current price.
struct Position: Identifiable, Codable, Hashable {
    var id = UUID()
    var costUSDC: Double
    var quantity: Double

    var entryPrice: Double { quantity > 0 ? costUSDC / quantity : 0 }
    func value(at price: Double) -> Double { quantity * price }
    func pnl(at price: Double) -> Double { value(at: price) - costUSDC }
    func pnlPercent(at price: Double) -> Double { costUSDC > 0 ? pnl(at: price) / costUSDC * 100 : 0 }
}
