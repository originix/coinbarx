import Foundation

struct Asset: Identifiable, Hashable, Codable {
    let mint: String
    let label: String

    var id: String { mint }
}

extension Asset {
    static let tracked: [Asset] = [
        Asset(mint: "So11111111111111111111111111111111111111112", label: "SOL"),
    ]
}

/// Latest price and 24h change for an asset.
struct Quote {
    let lastPrice: Double
    let priceChangePercent: Double
}

struct Position: Identifiable, Codable, Hashable {
    var id = UUID()
    var mint: String
    var costUSDC: Double
    var quantity: Double

    var entryPrice: Double { quantity > 0 ? costUSDC / quantity : 0 }
    func value(at price: Double) -> Double { quantity * price }
    func pnl(at price: Double) -> Double { value(at: price) - costUSDC }
    func pnlPercent(at price: Double) -> Double { costUSDC > 0 ? pnl(at: price) / costUSDC * 100 : 0 }
}

extension Position {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        mint = (try? c.decode(String.self, forKey: .mint)) ?? "So11111111111111111111111111111111111111112"
        costUSDC = try c.decode(Double.self, forKey: .costUSDC)
        quantity = try c.decode(Double.self, forKey: .quantity)
    }
}
