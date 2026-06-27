import SwiftUI

/// Owns ticker state and the polling loop. `@MainActor` so published changes happen on
/// the main thread, where SwiftUI reads them.
@MainActor
final class TickerViewModel: ObservableObject {
    /// Latest quote per mint. Kept across network errors rather than blanked out.
    @Published private(set) var quotes: [String: Quote] = [:]
    @Published private(set) var lastUpdated: Date?

    /// True when the most recent fetch failed (prices shown are stale, not blank).
    @Published private(set) var isOffline = false

    /// User-entered buy positions (against the primary asset). Persisted to UserDefaults.
    @Published var positions: [Position] = [] {
        didSet { savePositions() }
    }

    let assets: [Asset]

    private var timer: Timer?
    private let pollInterval: TimeInterval = 10
    private let positionsKey = "positions"

    init(assets: [Asset] = Asset.tracked) {
        self.assets = assets
        loadPositions()
        start()
    }

    deinit {
        timer?.invalidate()
    }

    var primary: Asset? { assets.first }

    /// Current price of the primary asset, if loaded — used for P&L.
    var primaryPrice: Double? {
        guard let primary else { return nil }
        return quotes[primary.mint]?.lastPrice
    }

    /// Compact primary price for the menu bar ("…" before the first load).
    var menuBarPrice: String {
        guard let price = primaryPrice else { return "…" }
        return PriceFormat.string(price, grouping: false)
    }

    // MARK: - Positions

    func addPosition(costUSDC: Double, quantity: Double) {
        guard costUSDC > 0, quantity > 0 else { return }
        positions.append(Position(costUSDC: costUSDC, quantity: quantity))
    }

    func removePosition(_ position: Position) {
        positions.removeAll { $0.id == position.id }
    }

    func totalCost() -> Double { positions.reduce(0) { $0 + $1.costUSDC } }
    func totalPnL(at price: Double) -> Double {
        positions.reduce(0) { $0 + $1.pnl(at: price) }
    }

    private func loadPositions() {
        guard let data = UserDefaults.standard.data(forKey: positionsKey),
              let decoded = try? JSONDecoder().decode([Position].self, from: data) else { return }
        positions = decoded
    }

    private func savePositions() {
        guard let data = try? JSONEncoder().encode(positions) else { return }
        UserDefaults.standard.set(data, forKey: positionsKey)
    }

    private func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        Task { await refreshAll() }
    }

    private func refreshAll() async {
        guard let fetched = await Self.fetch(assets), !fetched.isEmpty else {
            isOffline = true        // keep last good prices, just flag the failure
            return
        }
        for (mint, quote) in fetched { quotes[mint] = quote }
        lastUpdated = Date()
        isOffline = false
    }

    /// Jupiter Price V3 — free, no API key, Solana on-chain pricing. One request returns
    /// every mint, keyed by mint address, each with `usdPrice` and `priceChange24h`.
    private static func fetch(_ assets: [Asset]) async -> [String: Quote]? {
        let ids = assets.map(\.mint).joined(separator: ",")
        guard let url = URL(string: "https://lite-api.jup.ag/price/v3?ids=\(ids)") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let prices = try JSONDecoder().decode([String: JupiterPrice].self, from: data)
            return prices.mapValues { Quote(lastPrice: $0.usdPrice, priceChangePercent: $0.priceChange24h) }
        } catch {
            return nil
        }
    }
}

private struct JupiterPrice: Decodable {
    let usdPrice: Double
    let priceChange24h: Double
}
