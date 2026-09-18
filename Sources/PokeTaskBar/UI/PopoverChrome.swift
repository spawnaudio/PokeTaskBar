import AppKit
import SwiftUI

/// Popover material (`NSVisualEffectView.Material.popover`) so the menu-bar panel
/// follows system light/dark instead of an opaque window fill.
@MainActor
struct PopoverMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Shared 0.5pt hairline so buttons, chips, tabs, and cards all read as bordered.
enum TahoeHairline {
    static let width: CGFloat = 1
    static let idle = Color(nsColor: MenuBarPanelMetrics.hairline)
    static let selected = Color(nsColor: MenuBarPanelMetrics.hairlineSelected)

    static func tinted(_ color: Color) -> Color { color.opacity(0.45) }
}

/// Fill + stroke on one shape so  hairlines stay closed (sibling overlays clip corners).
struct TahoeStrokedFill<S: InsettableShape>: View {
    var shape: S
    var fill: Color
    var stroke: Color = TahoeHairline.idle
    var lineWidth: CGFloat = TahoeHairline.width

    var body: some View {
        shape.fill(fill)
            .overlay {
                shape.strokeBorder(stroke, lineWidth: lineWidth)
            }
    }
}

/// Ultra-thin divider between Linear tab chrome and the list. Hidden until the pointer is near it.
@MainActor
struct HoverHairlineSeparator: View {
    @State private var hovering = false

    var body: some View {
        Color.clear
            .frame(height: 12)
            .overlay {
                Rectangle()
                    .fill(TahoeHairline.idle)
                    .frame(height: TahoeHairline.width)
                    .opacity(hovering ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .accessibilityHidden(true)
    }
}

/// Opaque card: 12pt continuous corners + hairline.
@MainActor
struct PopoverCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                TahoeStrokedFill(
                    shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                    fill: Color(nsColor: MenuBarPanelMetrics.cardFill))
            }
    }
}

/// Primary / secondary / toolbar buttons. Linear filled / chip / plain.
enum TahoeButtonKind {
    case prominent
    case regular
    case accessory
}

/// Capsule fill + hairline + `contentShape` around a label. Buttons wrap this in a
/// `ButtonStyle` so padding hits; Menu labels apply it directly on the label.
struct TahoeCapsuleChrome<Content: View>: View {
    var kind: TahoeButtonKind
    var expands: Bool = false
    var tint: Color? = nil
    var pressed: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = Capsule()
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: expands ? .infinity : nil, alignment: expands ? .leading : .center)
            .background {
                TahoeStrokedFill(shape: shape, fill: fill, stroke: stroke)
            }
            .contentShape(shape)
            .opacity(pressed ? 0.72 : 1)
    }

    private var horizontalPadding: CGFloat {
        switch kind {
        case .prominent: return 10
        case .regular: return 8
        case .accessory: return 6
        }
    }

    private var verticalPadding: CGFloat {
        switch kind {
        case .prominent, .regular: return 6
        case .accessory: return 4
        }
    }

    private var fill: Color {
        switch kind {
        case .prominent: return Color(nsColor: MenuBarPanelMetrics.selectedFill)
        case .regular: return tint?.opacity(0.16) ?? Color(nsColor: MenuBarPanelMetrics.chipFill)
        case .accessory: return Color.clear
        }
    }

    private var stroke: Color {
        switch kind {
        case .prominent: return TahoeHairline.selected
        case .regular: return tint.map(TahoeHairline.tinted) ?? TahoeHairline.idle
        case .accessory: return TahoeHairline.idle
        }
    }
}

/// Hit region = drawn capsule. Chrome lives on `configuration.label`, not outside `.plain`.
struct TahoeChromeButtonStyle: ButtonStyle {
    var kind: TahoeButtonKind
    var expands: Bool = false
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        TahoeCapsuleChrome(
            kind: kind,
            expands: expands,
            tint: tint,
            pressed: configuration.isPressed
        ) {
            configuration.label
        }
    }
}

/// Segmented tab / duration chips. Selected fill + full-capsule hit target.
struct LinearSegmentButtonStyle: ButtonStyle {
    var selected: Bool
    var expands: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: expands ? .infinity : nil)
            .background {
                TahoeStrokedFill(
                    shape: shape,
                    fill: selected ? Color(nsColor: MenuBarPanelMetrics.selectedFill) : Color.clear,
                    stroke: selected ? TahoeHairline.selected : TahoeHairline.idle)
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

/// Circular toolbar icons. Hit region is the full circle, not the SF Symbol.
struct TahoeIconButtonStyle: ButtonStyle {
    var selected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = Circle()
        configuration.label
            .background {
                TahoeStrokedFill(
                    shape: shape,
                    fill: selected ? Color(nsColor: MenuBarPanelMetrics.selectedFill) : Color.clear,
                    stroke: selected ? TahoeHairline.selected : TahoeHairline.idle)
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

/// Layout-only cluster.
@MainActor
struct TahoeGlassCluster<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View { content }
}

extension View {
    func popoverCard() -> some View {
        modifier(PopoverCardModifier())
    }

    /// Quiet bordered pill for **Menu labels** (chrome on the label, not the Menu).
    func linearChipChrome(expands: Bool = false, tint: Color? = nil) -> some View {
        TahoeCapsuleChrome(kind: .regular, expands: expands, tint: tint) { self }
    }

    /// Segmented Button chrome. Hit region matches the drawn pill.
    func linearSegmentChrome(selected: Bool, expands: Bool = false) -> some View {
        buttonStyle(LinearSegmentButtonStyle(selected: selected, expands: expands))
    }

    /// Toolbar strip: filled control surface + hairline.
    func popoverBottomBarChrome() -> some View {
        self
            .background {
                TahoeStrokedFill(
                    shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                    fill: Color(nsColor: MenuBarPanelMetrics.chipFill))
            }
    }

    /// Button chrome. Prominent = filled control; regular = chip; accessory = plain.
    func tahoeButtonStyle(_ kind: TahoeButtonKind) -> some View {
        buttonStyle(TahoeChromeButtonStyle(kind: kind))
    }

    /// Overlay island / prompt chrome: filled panel.
    func tahoeFloatingChrome(cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background {
                TahoeStrokedFill(shape: shape, fill: Color.primary.opacity(0.08))
            }
    }

    func tahoePromptChrome(cornerRadius: CGFloat = 10) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background {
                TahoeStrokedFill(shape: shape, fill: Color.primary.opacity(0.08))
            }
    }

    func tahoeIconChrome(selected: Bool = false) -> some View {
        buttonStyle(TahoeIconButtonStyle(selected: selected))
    }
}

enum TahoeChromeSymbol {
    /// Trailing menu affordance on popup chips.
    static let menuChevron = "chevron.down"
}

/// Quiet popup label: current value plus a trailing chevron.
@MainActor
struct TahoeMenuLabel: View {
    let text: String
    var expands: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .lineLimit(1)
            if expands { Spacer(minLength: 4) }
            Image(systemName: TahoeChromeSymbol.menuChevron)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .accessibilityHidden(true)
        }
    }
}

/// Menu-styled picker as a quiet bordered chip with a chevron.
@MainActor
struct TahoePopupMenu<Selection: Hashable, Content: View>: View {
    let accessibilityLabel: String
    let selectionTitle: String
    @Binding var selection: Selection
    var size: ControlSize = .small
    var expands: Bool = false
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            Picker(accessibilityLabel, selection: $selection) {
                content
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            TahoeMenuLabel(text: selectionTitle, expands: expands)
                .foregroundStyle(tint ?? Color.primary)
                .linearChipChrome(expands: expands, tint: tint)
        }
        .menuIndicator(.hidden)
        .controlSize(size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selectionTitle)
    }
}

struct TahoeTabItem<Value: Hashable> {
    let value: Value
    let title: String
    var symbol: String? = nil
    var symbolColor: Color? = nil

    init(_ value: Value, title: String, symbol: String? = nil, symbolColor: Color? = nil) {
        self.value = value
        self.title = title
        self.symbol = symbol
        self.symbolColor = symbolColor
    }
}

/// Selected = filled quiet pill, idle = no fill. Labels collapse to icons
/// when the labeled cluster would wrap. `expands` splits width evenly and
/// follows the window.
@MainActor
struct TahoeTabBar<Value: Hashable>: View {
    @Binding var selection: Value
    var size: ControlSize = .small
    var expands: Bool = false
    let items: [TahoeTabItem<Value>]

    private var canCollapseToIcons: Bool {
        items.allSatisfy { $0.symbol != nil }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tabRow(showTitle: true)
                .fixedSize(horizontal: !expands, vertical: false)
            if canCollapseToIcons {
                tabRow(showTitle: false)
            }
        }
        .frame(maxWidth: expands ? .infinity : nil)
    }

    private func tabRow(showTitle: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.value) { item in
                let selected = selection == item.value
                Button {
                    selection = item.value
                } label: {
                    HStack(spacing: 5) {
                        if let symbol = item.symbol {
                            Image(systemName: symbol)
                                .foregroundStyle(
                                    item.symbolColor ?? (selected ? Color.primary : Color.secondary))
                        }
                        if showTitle {
                            Text(item.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .frame(maxWidth: expands ? .infinity : nil)
                }
                .font(.system(size: 13, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .linearSegmentChrome(selected: selected, expands: expands)
                .controlSize(size)
                .frame(maxWidth: expands ? .infinity : nil)
                .help(item.title)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// 24–28pt metadata pill: quiet border, optional team/status tint.
@MainActor
struct LinearTagChip: View {
    let text: String
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint ?? Color.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
        .padding(.vertical, 4)
            .background {
                TahoeStrokedFill(
                    shape: Capsule(),
                    fill: tint?.opacity(0.16) ?? Color(nsColor: MenuBarPanelMetrics.chipFill),
                    stroke: tint.map(TahoeHairline.tinted) ?? TahoeHairline.idle)
            }
            .contentShape(Capsule())
    }
}

/// Muted label, brighter value — inspector / composer property rows.
@MainActor
struct LinearPropertyRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            value
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

/// Caption2 tertiary labels for Focus / Usage section headers.
@MainActor
struct PopoverSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

/// Muted track + accent fill (shadcn-style). Limits keep their own warn/crit tints.
@MainActor
struct MutedProgressBar: View {
    var value: Double
    var total: Double = 1

    var body: some View {
        let fraction = total > 0 ? min(max(value / total, 0), 1) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                TahoeStrokedFill(
                    shape: Capsule(),
                    fill: Color.primary.opacity(0.08))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(4, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .accessibilityValue(Text("\(Int((fraction * 100).rounded()))%"))
    }
}

@MainActor
struct FocusPauseButton: View {
    let paused: Bool
    let disabled: Bool
    let pauseTitle: String
    let resumeTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                Label(paused ? resumeTitle : pauseTitle,
                      systemImage: paused ? "play.fill" : "pause.fill")
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: paused ? "play.fill" : "pause.fill")
            }
        }
        .tahoeButtonStyle(.prominent)
        .controlSize(.regular)
        .disabled(disabled)
        .help(paused ? resumeTitle : pauseTitle)
        .accessibilityLabel(paused ? resumeTitle : pauseTitle)
    }
}

/// Linear filled primary for Mark done (Today / Focus). Lists stay unboxed.
@MainActor
struct FocusMarkDoneButton: View {
    let title: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .tahoeButtonStyle(.prominent)
            .controlSize(.regular)
            .disabled(disabled)
    }
}

@MainActor
struct PopoverShellToolbar: View {
    @Environment(PopoverNavigation.self) private var nav
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @Environment(UsageStore.self) private var store

    private var l: L { companion.l }

    var body: some View {
        @Bindable var nav = nav
        HStack(spacing: 8) {
            if nav.canGoBack {
                Button {
                    nav.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .tahoeIconChrome()
                .help(l.goBack)
                .accessibilityLabel(l.goBack)
            }

            ViewThatFits(in: .horizontal) {
                tabRow(showTitle: true)
                    .fixedSize(horizontal: true, vertical: false)
                tabRow(showTitle: false)
            }
            Spacer(minLength: 8)

            iconButton(
                systemName: store.menuBarPanelDetached ? "menubar.arrow.up.rectangle" : "macwindow.on.rectangle",
                help: store.menuBarPanelDetached ? l.attachMenuBarPanel : l.detachMenuBarPanel,
                label: store.menuBarPanelDetached ? l.attachMenuBarPanel : l.detachMenuBarPanel,
                selected: store.menuBarPanelDetached
            ) {
                store.menuBarPanelDetached.toggle()
            }
            iconButton(systemName: "calendar", help: l.todayDeskMenuOpen, label: l.todayDeskWindowTitle) {
                session.openDesk()
            }
            iconButton(systemName: "gearshape", help: l.settings, label: l.settings, selected: nav.showSettings) {
                nav.showSettings = true
            }
        }
    }

    private func iconButton(
        systemName: String,
        help: String,
        label: String,
        selected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .frame(width: 32, height: 32)
        }
        .tahoeIconChrome(selected: selected)
        .help(help)
        .accessibilityLabel(label)
    }

    private func tabRow(showTitle: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                let selected = !nav.showSettings && nav.tab == tab
                Button {
                    nav.showSettings = false
                    nav.tab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                        if showTitle {
                            Text(tab.title(l))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                }
                .linearSegmentChrome(selected: selected)
                .help(tab.title(l))
                .accessibilityLabel(tab.title(l))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
