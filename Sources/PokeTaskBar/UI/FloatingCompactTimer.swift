import SwiftUI

/// The folded timer groups the clock, pause, expand, and New Linear Issue actions.
@MainActor
struct FloatingCompactTimer: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if let current = session.session {
            let theme = MenuBarTheme(scheme: scheme)
            let l = companion.l
            let paused = current.userPaused || current.phase == .paused
            HStack(spacing: 2) {
                FloatingTimerClock(compact: true)
                    .frame(width: 60, height: 28, alignment: .leading)

                Button { session.togglePause() } label: {
                    Image(systemName: paused ? "play" : "pause")
                }
                .buttonStyle(FloatingTimerButtonStyle(selected: paused))
                .disabled(current.phase == .awaitingChoice)
                .help(paused ? l.resumeTimer : l.pauseTimer)
                .accessibilityLabel(paused ? l.resumeTimer : l.pauseTimer)

                Button { store.floatingPetIslandFolded = false } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(FloatingTimerButtonStyle())
                .help(l.expandTimer).accessibilityLabel(l.expandTimer)
                FloatingTimerNewIssueButton()
            }
            .font(.system(size: 11))
            .frame(width: FloatingPetController.compactTimerWidth,
                   height: FloatingPetController.islandFoldedClockHeight)
            .background(theme.canvas, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(contrast == .increased ? theme.secondary : theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Pet-only uses a timer glyph; expanded/setup states keep their fold/cancel action.
@MainActor
struct FloatingPetTimerToggle: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(FloatingPetTimerToggleStyle())
        .help(label).accessibilityLabel(label)
    }
}

private struct FloatingPetTimerToggleStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let theme = MenuBarTheme(scheme: scheme)
        configuration.label
            .foregroundStyle(hovering || configuration.isPressed ? theme.text : theme.secondary)
            .frame(width: FloatingPetController.islandFoldChevronSize,
                   height: FloatingPetController.islandFoldChevronSize)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? theme.border : hovering ? theme.selected : theme.canvas)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(contrast == .increased ? theme.secondary : theme.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
