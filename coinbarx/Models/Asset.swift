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
