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

    @Published private(set) var assets: [Asset] = []

    @Published private(set) var displayIndex = 0

    @Published var rotates = false {
        didSet {
            UserDefaults.standard.set(rotates, forKey: rotatesKey)
            if !rotates { displayIndex = 0 }
        }
    }

    private var timer: Timer?
    private var rotateTimer: Timer?
    private let pollInterval: TimeInterval = 10
    private let rotateInterval: TimeInterval = 6
    private let positionsKey = "positions"
    private let assetsKey = "assets"
    private let rotatesKey = "rotates"

    init() {
        rotates = UserDefaults.standard.bool(forKey: rotatesKey)
        loadAssets()
        loadPositions()
        start()
    }

    deinit {
        timer?.invalidate()
        rotateTimer?.invalidate()
    }

    var primary: Asset? { assets.first }

    /// Current price of the primary asset, if loaded — used for P&L.
    var primaryPrice: Double? {
        guard let primary else { return nil }
        return quotes[primary.mint]?.lastPrice
    }

    /// The token currently shown in the menu bar. Rotates through `assets` over time.
    var displayAsset: Asset? {
        guard !assets.isEmpty else { return nil }
        return assets[min(displayIndex, assets.count - 1)]
    }

    /// Menu bar text for the current token, e.g. "SOL 152.34" ("…" before first load).
    var menuBarTitle: String {
        guard let asset = displayAsset else { return "coinbarx" }
        guard let quote = quotes[asset.mint] else { return "\(asset.label) …" }
        return "\(asset.label) \(PriceFormat.string(quote.lastPrice, grouping: false))"
    }

    /// Advance to the next token (called by the rotate timer).
    func advanceDisplay() {
        guard rotates, assets.count > 1 else { displayIndex = 0; return }
        displayIndex = (displayIndex + 1) % assets.count
    }

    // MARK: - Positions

    func addPosition(mint: String, costUSDC: Double, quantity: Double) {
        guard !mint.isEmpty, costUSDC > 0, quantity > 0 else { return }
        positions.append(Position(mint: mint, costUSDC: costUSDC, quantity: quantity))
    }

    func removePosition(_ position: Position) {
        positions.removeAll { $0.id == position.id }
    }

    /// Current price for a token, if loaded.
    func price(for mint: String) -> Double? { quotes[mint]?.lastPrice }

    func totalCost() -> Double { positions.reduce(0) { $0 + $1.costUSDC } }

    /// Portfolio value now: each position at its token's price (falls back to cost if
    /// that token has no price yet, so a missing quote doesn't distort the total).
    func totalValue() -> Double {
        positions.reduce(0) { sum, p in
            sum + (price(for: p.mint).map { p.value(at: $0) } ?? p.costUSDC)
        }
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

    // MARK: - Tokens

    /// Add a token. Ignores blanks and duplicate mints; refreshes so its price loads.
    func addAsset(mint: String, label: String) {
        let mint = mint.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mint.isEmpty, !label.isEmpty,
              !assets.contains(where: { $0.mint == mint }) else { return }
        assets.append(Asset(mint: mint, label: label))
        saveAssets()
        refresh()
    }

    func removeAsset(_ asset: Asset) {
        assets.removeAll { $0.mint == asset.mint }
        quotes[asset.mint] = nil
        saveAssets()
    }

    private func loadAssets() {
        if let data = UserDefaults.standard.data(forKey: assetsKey),
           let decoded = try? JSONDecoder().decode([Asset].self, from: data), !decoded.isEmpty {
            assets = decoded
        } else {
            assets = Asset.tracked
        }
    }

    private func saveAssets() {
        guard let data = try? JSONEncoder().encode(assets) else { return }
        UserDefaults.standard.set(data, forKey: assetsKey)
    }

    private func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        rotateTimer = Timer.scheduledTimer(withTimeInterval: rotateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advanceDisplay() }
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
