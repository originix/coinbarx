# CLAUDE.md

Guidance for working in this repo.

## What this is

coinbarx — a native SwiftUI macOS menu bar app showing live crypto prices. Menu
bar–only (no Dock icon), zero third-party dependencies.

## Build & run

```bash
# Build
xcodebuild -project coinbarx.xcodeproj -scheme coinbarx -configuration Debug build

# Launch the built app
open ~/Library/Developer/Xcode/DerivedData/coinbarx-*/Build/Products/Debug/coinbarx.app

# Quit a running instance
pkill -x coinbarx          # or use the Quit button (⌘Q) in the dropdown
```

There are no tests and no package manager — it's a single Xcode app target.

## Layout

```
coinbarx.xcodeproj/         Xcode project (project.pbxproj is hand-generated, not from a template)
coinbarx/
  coinbarxApp.swift         @main entry; MenuBarExtra (icon + price) -> DropdownView
  Models/Asset.swift        Asset (mint + label), Quote, and the tracked-token list
  ViewModels/
    TickerViewModel.swift   @MainActor ObservableObject: 10s Timer, fetch, state
  Views/DropdownView.swift  Dropdown UI, AssetRow, SolanaMark (Shape), PriceFormat
  Info.plist                LSUIElement = YES (menu-bar-only)
  coinbarx.entitlements     App Sandbox + network client
```

MVVM: Models = data, ViewModels = logic/state, Views = UI. Disk folders mirror the
Xcode groups.

## How it works

`TickerViewModel` polls Jupiter Price V3 every 10s, decodes prices into
`@Published var quotes`, and SwiftUI redraws the menu bar + dropdown. On a network
error the last good values are kept (never blanked).

## Conventions / gotchas

- **Adding a token:** append one `Asset(mint:label:)` line to `Asset.tracked` in
  `Models/Asset.swift`. The first entry is the menu bar's primary. Nothing else changes.
- **Data source:** Jupiter Price V3 (`https://lite-api.jup.ag/price/v3?ids=<mints>`),
  keyed by SPL mint, fields `usdPrice` + `priceChange24h`. Binance is the documented
  fallback in `TickerViewModel.fetch(_:)`.
- **Swift language mode is 5.0** (not 6) — chosen to avoid strict-concurrency errors on
  the `Timer` closure. Code is still `@MainActor` + async/await.
- **`ImageRenderer` is `@MainActor`** — `SolanaIcon.menuBar` must stay main-actor isolated.
- **Deployment target is macOS 13.0.** Keep APIs within that floor (`MenuBarExtra` is 13+).
- The menu bar icon is drawn (`SolanaMark`), not an image asset. `Assets.xcassets`
  AppIcon is an empty placeholder — irrelevant for an LSUIElement agent.
- `project.pbxproj` object IDs are deterministic 24-char hex; if you regenerate it, keep
  the native target's BlueprintIdentifier in sync with the shared scheme.
