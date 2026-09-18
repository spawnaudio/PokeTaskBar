import SwiftUI

/// Linear-inspired surfaces scoped to the menu-bar window. Other windows keep
/// their existing chrome, including the user's status-item pill appearance.
struct MenuBarTheme {
    let scheme: ColorScheme

    var shell: Color { color(light: 0xF3F4F6, dark: 0x17181B) }
    var canvas: Color { color(light: 0xFFFFFF, dark: 0x1F2023) }
    var surface: Color { color(light: 0xF7F8FA, dark: 0x242529) }
    var selected: Color { color(light: 0xE7E9EE, dark: 0x303138) }
    var border: Color { color(light: 0xDDE0E6, dark: 0x383A40) }
    var divider: Color { color(light: 0xE9EBEF, dark: 0x2B2C31) }
    var text: Color { color(light: 0x202126, dark: 0xF1F1F3) }
    var secondary: Color { color(light: 0x60636C, dark: 0xA2A4AD) }
    var accent: Color { color(light: 0x086C7D, dark: 0x35C2D7) }

    private func color(light: UInt32, dark: UInt32) -> Color {
        let hex = scheme == .dark ? dark : light
        return Color(.sRGB, red: Double((hex >> 16) & 255) / 255,
                     green: Double((hex >> 8) & 255) / 255,
                     blue: Double(hex & 255) / 255, opacity: 1)
    }
}

/// The AppKit-backed linear indicator can ignore tint on macOS. Draw the same
/// small track in SwiftUI while retaining ProgressView's accessible value.
struct MenuBarProgressStyle: ProgressViewStyle {
    var tint: Color? = nil
    @Environment(\.menuBarChrome) private var menuBarChrome
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        if menuBarChrome {
            GeometryReader { geometry in
                Capsule().fill(MenuBarTheme(scheme: scheme).selected)
                    .overlay(alignment: .leading) {
                        Capsule().fill(tint ?? MenuBarTheme(scheme: scheme).accent)
                            .frame(width: geometry.size.width * min(1, max(0, configuration.fractionCompleted ?? 0)))
                    }
            }
            .frame(height: 4)
        } else {
            LinearProgressViewStyle().makeBody(configuration: configuration)
        }
    }
}

private struct MenuBarChromeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var menuBarChrome: Bool {
        get { self[MenuBarChromeKey.self] }
        set { self[MenuBarChromeKey.self] = newValue }
    }
}

@MainActor
struct MenuBarDivider: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let theme = MenuBarTheme(scheme: scheme)
        Rectangle()
            .fill(contrast == .increased ? theme.secondary : theme.divider)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Full-row controls retain native Button keyboard/focus behavior and make the
/// whole visible rectangle clickable, including whitespace around the label.
struct MenuBarButtonStyle: ButtonStyle {
    var prominent = false
    var bordered = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let theme = MenuBarTheme(scheme: scheme)
        configuration.label
            .font(.system(size: 13, weight: prominent ? .medium : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(prominent || configuration.isPressed ? theme.selected : theme.surface)
                    .overlay {
                        if bordered {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(contrast == .increased ? theme.secondary : theme.border)
                        }
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}
