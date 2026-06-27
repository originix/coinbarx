import SwiftUI

/// A menu bar–only app (see `LSUIElement` in Info.plist — no Dock icon). The menu bar
/// shows the Solana mark + primary price; clicking it opens the dropdown.
@main
struct coinbarxApp: App {
    @StateObject private var viewModel = TickerViewModel()

    var body: some Scene {
        MenuBarExtra {
            DropdownView(viewModel: viewModel)
        } label: {
            Text("◎ \(viewModel.menuBarPrice)")
        }
        .menuBarExtraStyle(.window)
    }
}
