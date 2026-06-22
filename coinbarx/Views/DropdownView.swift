import SwiftUI

/// The Solana mark: three slanted bars, drawn as a Shape (no image assets).
struct SolanaMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gap = rect.height * 0.16
        let bar = (rect.height - 2 * gap) / 3
        let skew = rect.width * 0.22
        for i in 0..<3 {
            let y = (bar + gap) * CGFloat(i)
            if i == 1 {                                   // middle bar leans left
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width - skew, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y + bar))
                path.addLine(to: CGPoint(x: skew, y: y + bar))
            } else {                                      // top & bottom bars lean right
                path.move(to: CGPoint(x: skew, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
                path.addLine(to: CGPoint(x: rect.width - skew, y: y + bar))
                path.addLine(to: CGPoint(x: 0, y: y + bar))
            }
            path.closeSubpath()
        }
        return path
    }
}

/// Template NSImage of the Solana mark for the menu bar (recolored to match light/dark).
enum SolanaIcon {
    @MainActor static let menuBar: NSImage = {
        let renderer = ImageRenderer(content: SolanaMark().frame(width: 14, height: 12))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }()
}

/// Price formatting with adaptive precision (sub-cent tokens get more decimals).
enum PriceFormat {
    static func string(_ value: Double, grouping: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        let digits: Int
        switch abs(value) {
        case 0..<0.01: digits = 6
        case 0.01..<1: digits = 4
        default:       digits = 2
        }
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

/// The window shown when the menu bar item is clicked.
struct DropdownView: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                if index > 0 { Divider() }
                AssetRow(asset: asset, quote: viewModel.quotes[asset.mint])
            }

            Divider().padding(.vertical, 4)
            footer
        }
        .padding(12)
        .frame(width: 260)
    }

    private var footer: some View {
        HStack {
            Text(updatedText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: viewModel.refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .keyboardShortcut("q")
                .help("Quit coinbarx")
        }
    }

    private var updatedText: String {
        guard let date = viewModel.lastUpdated else { return "updating…" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "updated \(formatter.string(from: date))"
    }
}

/// One asset row: label on the left, price + colored 24h change on the right.
private struct AssetRow: View {
    let asset: Asset
    let quote: Quote?

    var body: some View {
        HStack(spacing: 8) {
            SolanaMark()
                .frame(width: 16, height: 14)
                .foregroundStyle(.primary)
            Text(asset.label)
                .font(.headline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(priceText)
                    .monospacedDigit()
                    .font(.body.weight(.medium))
                changeView
            }
        }
        .padding(.vertical, 6)
    }

    private var priceText: String {
        guard let quote else { return "—" }
        return "$" + PriceFormat.string(quote.lastPrice)
    }

    @ViewBuilder
    private var changeView: some View {
        if let quote {
            let up = quote.priceChangePercent >= 0
            Text(String(format: "%@ %.2f%%", up ? "▲" : "▼", abs(quote.priceChangePercent)))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(up ? Color.green : Color.red)
        } else {
            Text("—").font(.caption).foregroundStyle(.secondary)
        }
    }
}
