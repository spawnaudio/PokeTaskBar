import AppKit
import SwiftUI

/// One editable clock shared by setup, expanded, and compact floating timers.
@MainActor
struct FloatingTimerClock: View {
    var compact = false
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @Environment(\.colorScheme) private var scheme
    @State private var editing = false

    var body: some View {
        let theme = MenuBarTheme(scheme: scheme)
        let clock = session.isActive ? session.clockDisplay()
            : (text: FocusClock.format(TimeInterval(session.plannedMinutes * 60)), overtime: false)
        let paused = session.session?.userPaused == true || session.session?.phase == .paused
        Button { editing = true } label: {
            HStack(spacing: 3) {
                Text(clock.text)
                    .font(.system(size: compact ? 16 : 18, weight: .medium).monospacedDigit())
                    .foregroundStyle(paused ? theme.secondary : theme.text)
                if clock.overtime {
                    Text(companion.l.overtimeAbbrev).font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
            .lineLimit(1).minimumScaleFactor(compact ? 0.7 : 0.8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(session.isActive ? companion.l.setTimeRemaining : companion.l.setTimerDuration)
        .accessibilityLabel(session.isActive ? companion.l.setTimeRemaining : companion.l.setTimerDuration)
        .accessibilityValue(clock.text)
        .accessibilityIdentifier("floating-timer-clock")
        .disabled(session.editableTimerMinuteRange == nil)
        .popover(isPresented: $editing, arrowEdge: .top) {
            FloatingTimerEditor()
                .environment(session).environment(companion)
        }
    }
}

@MainActor
struct FloatingTimerEditor: View {
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = ""
    @FocusState private var inputFocused: Bool

    private var value: Int? { Int(minutes.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var valid: Bool {
        guard let value, let range = session.editableTimerMinuteRange else { return false }
        return range.contains(value)
    }

    var body: some View {
        let l = companion.l
        let theme = MenuBarTheme(scheme: scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text(session.isActive ? l.setTimeRemaining : l.setTimerDuration)
                .font(.system(size: 12, weight: .medium))
            HStack(spacing: 6) {
                ForEach(SessionXP.plannedPresets, id: \.self) { preset in
                    Button(l.minutesValue(preset)) { apply(preset) }
                        .disabled(session.editableTimerMinuteRange?.contains(preset) != true)
                }
            }
            HStack {
                TextField(l.timerMinutesLabel, text: $minutes)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .accessibilityIdentifier("floating-timer-minutes")
                    .onSubmit { if valid, let value { apply(value) } }
                Text(l.timerMinutesLabel).foregroundStyle(theme.secondary)
            }
            if let range = session.editableTimerMinuteRange {
                Text(l.timerMinuteRange(range.lowerBound, range.upperBound))
                    .font(.system(size: 11)).foregroundStyle(theme.secondary)
            }
            HStack {
                Spacer()
                Button(l.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(l.save) { if let value { apply(value) } }
                    .keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(theme.text)
        .padding(14).frame(width: 248)
        .background(theme.canvas)
        .task {
            minutes = String(session.timerEditorMinutes)
            NSApp.activate(ignoringOtherApps: true)
            inputFocused = true
        }
    }

    private func apply(_ minutes: Int) {
        if session.setTimerMinutes(minutes) { dismiss() }
    }
}
