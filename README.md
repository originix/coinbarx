# coinbarx

Live crypto prices in your macOS menu bar. Native SwiftUI, zero dependencies.

coinbarx is a lightweight menu bar ticker. The menu bar shows the primary asset's
price; clicking it opens a dropdown with every tracked token, its price, and the 24h
change. No Dock icon, no window clutter — it just lives in your menu bar.

## Screenshot

> _Screenshot placeholder — drop a PNG here once you've run it._
>
> ![coinbarx menu bar dropdown](docs/screenshot.png)

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (built and tested with Xcode 26)

## Build & run

```bash
# Open in Xcode and press ⌘R
open coinbarx.xcodeproj

# …or build & launch from the command line
xcodebuild -project coinbarx.xcodeproj -scheme coinbarx -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/coinbarx-*/Build/Products/Debug/coinbarx.app
```

The app appears in the menu bar (no Dock icon — it's a `LSUIElement` agent). Prices
refresh every 10 seconds; use the dropdown's **Refresh** button to update on demand and
**Quit** (or ⌘Q) to exit.

## Adding a new token

Edit the `Asset.tracked` array in [`coinbarx/Models/Asset.swift`](coinbarx/Models/Asset.swift)
and append one line. `mint` is the SPL mint address; `label` is the display name; `glyph`
is an optional short symbol used in the menu bar:

```swift
static let tracked: [Asset] = [
    Asset(mint: "So11111111111111111111111111111111111111112", label: "SOL", glyph: "◎"),
    Asset(mint: "JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN", label: "JUP"),
    Asset(mint: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263", label: "BONK"),
    Asset(mint: "<mint>", label: "WIF"),   // ← add a token like this
]
```

The first entry is the **primary** token whose price shows in the menu bar (its `glyph`
is used there when set). The UI and polling pick up the rest automatically. Find mints on
Solscan / Jupiter and verify with `https://lite-api.jup.ag/price/v3?ids=<mint>`.

## Data source

Prices come from the free, key-less [Jupiter Price V3 API](https://station.jup.ag/docs/apis/price-api)
(Solana-native, on-chain pricing). A single request returns every tracked mint:

```
https://lite-api.jup.ag/price/v3?ids=<mint1>,<mint2>,…
```

coinbarx reads `usdPrice` and `priceChange24h` per mint. On a network error the last good
value is kept rather than blanking out.

> **Alternative source:** [Binance's public REST API](https://binance-docs.github.io/apidocs/spot/en/#24hr-ticker-price-change-statistics)
> (`/api/v3/ticker/24hr?symbol={PAIR}`) works too, but is keyed by trading pair rather
> than mint address. See the note in `TickerViewModel.fetch(_:)`.

## License

[MIT](LICENSE) © 2026 originix
