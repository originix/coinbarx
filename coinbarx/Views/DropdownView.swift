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

    /// Signed dollar amount, e.g. "+$134.50" / "-$80.00".
    static func signedUSD(_ value: Double) -> String {
        (value >= 0 ? "+$" : "-$") + string(abs(value))
    }

    /// Signed percent, e.g. "▲ 6.73%" / "▼ 2.10%".
    static func signedPercent(_ value: Double) -> String {
        String(format: "%@ %.2f%%", value >= 0 ? "▲" : "▼", abs(value))
    }
}

/// Gain/loss colors tuned for contrast in both light and dark menus.
extension Color {
    static let gain = Color(red: 0.16, green: 0.63, blue: 0.40)
    static let loss = Color(red: 0.84, green: 0.26, blue: 0.28)
}

/// The window shown when the menu bar item is clicked.
struct DropdownView: View {
    @ObservedObject var viewModel: TickerViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                if index > 0 { Divider() }
                AssetRow(asset: asset, quote: viewModel.quotes[asset.mint])
            }

            Divider().padding(.vertical, 8)
            PositionsView(viewModel: viewModel)

            if showSettings {
                Divider().padding(.vertical, 8)
                TokensView(viewModel: viewModel)
            }

            Divider().padding(.vertical, 8)
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                if viewModel.isOffline {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Text(updatedText)
                    .foregroundStyle(viewModel.isOffline ? .orange : .secondary)
            }
            .font(.caption)
            Spacer()
            Button { withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() } } label: {
                Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Manage tokens")

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
        guard let date = viewModel.lastUpdated else {
            return viewModel.isOffline ? "can't reach server" : "updating…"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let stamp = formatter.string(from: date)
        return viewModel.isOffline ? "offline · last \(stamp)" : "updated \(stamp)"
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
        .padding(.vertical, 2)
    }

    private var priceText: String {
        guard let quote else { return "—" }
        return "$" + PriceFormat.string(quote.lastPrice)
    }

    @ViewBuilder
    private var changeView: some View {
        if let quote {
            Text(PriceFormat.signedPercent(quote.priceChangePercent))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(quote.priceChangePercent >= 0 ? Color.gain : Color.loss)
        } else {
            Text("—").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Positions section: a scrollable list of buy positions with live P&L, a total
/// summary, and a sticky add form. Deleting asks for confirmation.
private struct PositionsView: View {
    @ObservedObject var viewModel: TickerViewModel
    @State private var selectedMint = ""
    @State private var costText = ""
    @State private var qtyText = ""

    private var isValid: Bool {
        !effectiveMint.isEmpty && (Double(costText) ?? 0) > 0 && (Double(qtyText) ?? 0) > 0
    }

    /// The picked token, or the first token if nothing valid is selected yet.
    private var effectiveMint: String {
        if viewModel.assets.contains(where: { $0.mint == selectedMint }) { return selectedMint }
        return viewModel.primary?.mint ?? ""
    }

    private func label(for mint: String) -> String {
        viewModel.assets.first { $0.mint == mint }?.label ?? "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POSITIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, -2)

            if viewModel.positions.isEmpty {
                Text("No positions yet — add one below.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.positions) { position in
                        PositionRow(position: position,
                                    label: label(for: position.mint),
                                    price: viewModel.price(for: position.mint)) {
                            viewModel.removePosition(position)
                        }
                    }
                }
                totalRow
            }

            Divider().padding(.top, 2)
            addForm
        }
    }

    private var totalRow: some View {
        let cost = viewModel.totalCost()
        let value = viewModel.totalValue()
        let pnl = value - cost
        let percent = cost > 0 ? pnl / cost * 100 : 0
        let up = pnl >= 0
        return VStack(spacing: 2) {
            HStack {
                Text("Total P&L").font(.caption.weight(.semibold))
                Spacer()
                Text(PriceFormat.signedUSD(pnl))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(up ? Color.gain : Color.loss)
            }
            HStack {
                Text("Value $\(PriceFormat.string(value))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(PriceFormat.signedPercent(percent))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(up ? Color.gain : Color.loss)
            }
        }
        .padding(.top, 4)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add a buy — token, USDC paid, amount received")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Picker("", selection: $selectedMint) {
                    ForEach(viewModel.assets) { asset in
                        Text(asset.label).tag(asset.mint)
                    }
                }
                .labelsHidden()
                .frame(width: 68)
                TextField("USDC", text: $costText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 40)
                    .onSubmit(add)
                TextField(label(for: effectiveMint), text: $qtyText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 40)
                    .onSubmit(add)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                    .fixedSize()
            }
        }
        .onAppear { if selectedMint.isEmpty { selectedMint = viewModel.primary?.mint ?? "" } }
    }

    private func add() {
        guard let cost = Double(costText), let qty = Double(qtyText) else { return }
        viewModel.addPosition(mint: effectiveMint, costUSDC: cost, quantity: qty)
        costText = ""
        qtyText = ""
    }
}

/// One position: cost → quantity and entry price on the left, live P&L on the right.
private struct PositionRow: View {
    let position: Position
    let label: String
    let price: Double?
    let onDelete: () -> Void

    @State private var confirming = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("$\(PriceFormat.string(position.costUSDC)) → \(PriceFormat.string(position.quantity)) \(label)")
                    .font(.caption)
                    .monospacedDigit()
                Text("entry $\(PriceFormat.string(position.entryPrice))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if confirming {
                Text("Delete?")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button { onDelete() } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.loss)
                .help("Confirm delete")
                Button { confirming = false } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Cancel")
            } else {
                pnlView
                Button { confirming = true } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .help("Remove position")
            }
        }
    }

    @ViewBuilder
    private var pnlView: some View {
        if let price {
            let up = position.pnl(at: price) >= 0
            VStack(alignment: .trailing, spacing: 1) {
                Text(PriceFormat.signedUSD(position.pnl(at: price)))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                Text(PriceFormat.signedPercent(position.pnlPercent(at: price)))
                    .font(.caption2)
                    .monospacedDigit()
            }
            .foregroundStyle(up ? Color.gain : Color.loss)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }
}

/// Settings: manage tracked tokens — list with remove, plus a label + mint add form.
private struct TokensView: View {
    @ObservedObject var viewModel: TickerViewModel
    @State private var labelText = ""
    @State private var mintText = ""

    private var isValid: Bool {
        !labelText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !mintText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOKENS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, -2)

            Toggle("Auto-rotate menu bar", isOn: $viewModel.rotates)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption)

            VStack(spacing: 8) {
                ForEach(viewModel.assets) { asset in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(asset.label)
                                .font(.caption.weight(.medium))
                            Text(asset.mint)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button { viewModel.removeAsset(asset) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                        .help("Remove \(asset.label)")
                    }
                }
            }

            Divider().padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Add token — label + SPL mint address")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("SOL", text: $labelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 52)
                        .onSubmit(add)
                    TextField("mint address", text: $mintText)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 40)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!isValid)
                        .fixedSize()
                }
            }
        }
    }

    private func add() {
        viewModel.addAsset(mint: mintText, label: labelText)
        labelText = ""
        mintText = ""
    }
}
