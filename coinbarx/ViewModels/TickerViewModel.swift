import SwiftUI

/// Owns ticker state and the polling loop. `@MainActor` so published changes happen on
/// the main thread, where SwiftUI reads them.
@MainActor
final class TickerViewModel: ObservableObject {
    /// Latest quote per mint. Kept across network errors rather than blanked out.
    @Published private(set) var quotes: [String: Quote] = [:]
    @Published private(set) var lastUpdated: Date?

    let assets: [Asset]

    private var timer: Timer?
    private let pollInterval: TimeInterval = 10

    init(assets: [Asset] = Asset.tracked) {
        self.assets = assets
        start()
    }

    deinit {
        timer?.invalidate()
    }

    var primary: Asset? { assets.first }

    /// Compact primary price for the menu bar ("…" before the first load).
    var menuBarPrice: String {
        guard let primary, let quote = quotes[primary.mint] else { return "…" }
        return PriceFormat.string(quote.lastPrice, grouping: false)
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
        guard let fetched = await Self.fetch(assets), !fetched.isEmpty else { return }
        for (mint, quote) in fetched { quotes[mint] = quote }
        lastUpdated = Date()
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
