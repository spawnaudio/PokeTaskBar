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
@MainActor
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
    @Environment(\.menuBarChrome) private var menuBarChrome
    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        Color.clear
            .frame(height: 12)
            .overlay {
                Rectangle()
                    .fill(menuBarChrome ? MenuBarTheme(scheme: scheme).divider : TahoeHairline.idle)
                    .frame(height: TahoeHairline.width)
                    .opacity(menuBarChrome || hovering ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .accessibilityHidden(true)
    }
}

/// Opaque card: 12pt continuous corners + hairline.
@MainActor
struct PopoverCardModifier: ViewModifier {
    @Environment(\.menuBarChrome) private var menuBarChrome
    @Environment(\.mainWindowChrome) private var mainWindowChrome
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                if mainWindowChrome {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MainWindowTheme(scheme: scheme).surface)
                } else {
                TahoeStrokedFill(
                    shape: RoundedRectangle(cornerRadius: menuBarChrome ? 8 : 12, style: .continuous),
                    fill: menuBarChrome ? MenuBarTheme(scheme: scheme).surface : Color(nsColor: MenuBarPanelMetrics.cardFill),
                    stroke: menuBarChrome ? MenuBarTheme(scheme: scheme).divider : TahoeHairline.idle)
                }
            }
    }
}

/// Focus pop-outs use the shared palette without changing the timer underneath.
/// Scope rectangular control chrome to the card's descendants only.
@MainActor
struct FocusPromptChromeModifier: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let theme = MenuBarTheme(scheme: scheme)
        content
            .font(.system(size: 12))
            .foregroundStyle(theme.text)
            .tint(theme.accent)
            .environment(\.menuBarChrome, true)
            .background {
                TahoeStrokedFill(
                    shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    fill: theme.canvas,
                    stroke: contrast == .increased ? theme.secondary : theme.border)
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
@MainActor
struct TahoeCapsuleChrome<Content: View>: View {
    @Environment(\.menuBarChrome) private var menuBarChrome
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    var kind: TahoeButtonKind
    var expands: Bool = false
    var tint: Color? = nil
    var pressed: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: menuBarChrome ? 7 : 100, style: .continuous)
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: expands ? .infinity : nil, alignment: expands ? .leading : .center)
            .background {
                TahoeStrokedFill(shape: shape, fill: fill, stroke: stroke)
            }
            .contentShape(shape)
            .opacity(enabled ? (pressed ? 0.72 : 1) : 0.45)
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
        if menuBarChrome {
            let theme = MenuBarTheme(scheme: scheme)
            switch kind {
            case .prominent: return theme.selected
            case .regular: return tint?.opacity(0.10) ?? theme.surface
            case .accessory: return .clear
            }
        }
        switch kind {
        case .prominent: return Color(nsColor: MenuBarPanelMetrics.selectedFill)
        case .regular: return tint?.opacity(0.16) ?? Color(nsColor: MenuBarPanelMetrics.chipFill)
        case .accessory: return Color.clear
        }
    }

    private var stroke: Color {
        if menuBarChrome {
            return tint?.opacity(0.30) ?? MenuBarTheme(scheme: scheme).border
        }
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
    @Environment(\.menuBarChrome) private var menuBarChrome
    @Environment(\.colorScheme) private var scheme
    var selected: Bool
    var expands: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: menuBarChrome ? 7 : 100, style: .continuous)
        let theme = MenuBarTheme(scheme: scheme)
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: expands ? .infinity : nil)
            .background {
                TahoeStrokedFill(
                    shape: shape,
                    fill: selected ? (menuBarChrome ? theme.selected : Color(nsColor: MenuBarPanelMetrics.selectedFill)) : Color.clear,
                    stroke: menuBarChrome ? theme.border : (selected ? TahoeHairline.selected : TahoeHairline.idle))
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

    /// Floating note composer. The timer strip owns its separate, unchanged chrome.
    func tahoeFloatingChrome(cornerRadius: CGFloat = 8) -> some View {
        modifier(FocusPromptChromeModifier(cornerRadius: cornerRadius))
    }

    func tahoePromptChrome(cornerRadius: CGFloat = 8) -> some View {
        modifier(FocusPromptChromeModifier(cornerRadius: cornerRadius))
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
    @Environment(\.menuBarChrome) private var menuBarChrome
    @Environment(\.colorScheme) private var scheme
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
                .foregroundStyle(menuBarChrome ? MenuBarTheme(scheme: scheme).text : (tint ?? Color.primary))
                .linearChipChrome(expands: expands, tint: tint)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
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

/// Linear Projects hexagon — same token `TahoeTabBar` uses when selected (`Color.primary`).
enum LinearChromeTint {
    static var project: Color { .primary }
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
    @Environment(CompanionStore.self) private var companion
    @Environment(UsageStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    private var l: L { companion.l }
    private var theme: MenuBarTheme { MenuBarTheme(scheme: scheme) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if nav.canGoBack {
                    iconButton("chevron.left", title: l.goBack) { nav.goBack() }
                } else if !store.menuBarPanelDetached {
                    Image(nsImage: MenuBarIcon.pokeBall)
                        .resizable().interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                }
                Text(nav.showSettings ? l.settings : "PokeTaskBar")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                iconButton(
                    store.menuBarPanelDetached ? "menubar.arrow.up.rectangle" : "macwindow.on.rectangle",
                    title: store.menuBarPanelDetached ? l.attachMenuBarPanel : l.detachMenuBarPanel
                ) { store.menuBarPanelDetached.toggle() }
                iconButton("gearshape", title: l.settings, selected: nav.showSettings) {
                    nav.showSettings.toggle()
                }
            }
            .padding(.leading, store.menuBarPanelDetached ? MenuBarPanelMetrics.detachedTrafficLightInset - 8 : 8)
            .padding(.trailing, 6)

            if !nav.showSettings {
                ViewThatFits(in: .horizontal) {
                    tabRow(showSymbols: true, showTitles: true).fixedSize(horizontal: true, vertical: false)
                    tabRow(showSymbols: false, showTitles: true).fixedSize(horizontal: true, vertical: false)
                    tabRow(showSymbols: true, showTitles: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
        .padding(.bottom, 4)
    }

    private func iconButton(_ symbol: String, title: String, selected: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .frame(width: 16, height: 16)
        }
        .buttonStyle(MenuBarButtonStyle(prominent: selected, bordered: false))
        .foregroundStyle(selected ? theme.text : theme.secondary)
        .help(title)
        .accessibilityLabel(title)
    }

    private func tabRow(showSymbols: Bool, showTitles: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                let selected = nav.tab == tab
                // Short visual label leaves room for all four tabs; VoiceOver keeps the full title.
                let title = tab == .usage ? l.menuBarUsage : tab.title(l)
                Button {
                    nav.tab = tab
                } label: {
                    HStack(spacing: 5) {
                        if showSymbols { Image(systemName: tab.symbol) }
                        if showTitles { Text(title).lineLimit(1) }
                    }
                    .font(.system(size: 12, weight: selected ? .medium : .regular))
                    .padding(.horizontal, 9)
                    .frame(height: 32)
                    .frame(maxWidth: showTitles ? nil : .infinity)
                    .foregroundStyle(selected ? theme.text : theme.secondary)
                    .background(selected ? theme.selected : Color.clear,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tab.title(l))
                .accessibilityLabel(tab.title(l))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

@MainActor
struct PopoverFooter: View {
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @Environment(UsageStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let l = companion.l
        HStack(spacing: 12) {
            Button { session.openDesk() } label: {
                Label(l.todayDeskMenuOpen, systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .help(l.todayDeskMenuOpen)
            Button {
                store.floatingPetEnabled.toggle()
            } label: {
                Image(systemName: store.floatingPetEnabled ? "eye" : "eye.slash")
            }
            .buttonStyle(.plain)
            .help(store.floatingPetEnabled ? l.floatingPetHideLabel : l.floatingPetEnableLabel)
            .accessibilityLabel(store.floatingPetEnabled ? l.floatingPetHideLabel : l.floatingPetEnableLabel)
            Spacer(minLength: 4)
            if store.linearIntegrationEnabled && store.linearAPIKeyConfigured {
                if store.isRefreshingLinearIssues {
                    ProgressView().controlSize(.mini).accessibilityLabel(l.refresh)
                } else if store.linearIssuesError != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .help(l.linearIssuesSyncFailed)
                        .accessibilityLabel(l.linearIssuesSyncFailed)
                } else if let date = store.linearIssuesUpdatedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                        RelativeTimestampText(date: date)
                    }
                    .help(l.linearLastSynced)
                    .accessibilityLabel(l.linearLastSynced)
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(MenuBarTheme(scheme: scheme).secondary)
        .frame(minHeight: 22)
    }
}
