import AppKit
import SwiftUI

/// A local draft: picking or cancelling never mutates a running session or its defaults.
@MainActor
struct FocusDurationPicker: View {
    let issueTitle: String
    let initialMinutes: Int
    var onStart: (Int) -> Void = { _ in }
    var onStartTask: ((String, String, Int) -> Void)? = nil
    @Environment(CompanionStore.self) private var companion
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = ""
    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @FocusState private var inputFocused: Bool
    @FocusState private var titleFocused: Bool

    private var selectedMinutes: Int? {
        guard let value = Int(minutes.trimmingCharacters(in: .whitespacesAndNewlines)),
              (SessionXP.minMinutes...SessionXP.maxMinutes).contains(value) else { return nil }
        return value
    }

    var body: some View {
        let l = companion.l
        let theme = MenuBarTheme(scheme: scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text(onStartTask == nil ? l.focusDuration : l.localTaskTimer).font(.system(size: 13, weight: .semibold))
            if onStartTask != nil {
                TextField(l.localTaskTitle, text: $taskTitle)
                    .textFieldStyle(.roundedBorder).focused($titleFocused)
                    .accessibilityIdentifier("local-task-title")
                TextField(l.localTaskDescription, text: $taskDescription, axis: .vertical)
                    .lineLimit(3...5).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("local-task-description")
                Text(l.localTaskPrivacy).font(.system(size: 11)).foregroundStyle(theme.secondary)
            } else {
                Text(issueTitle).foregroundStyle(theme.secondary).lineLimit(2)
            }
            HStack(spacing: 6) {
                ForEach(SessionXP.plannedPresets, id: \.self) { preset in
                    Button(l.minutesValue(preset)) { minutes = String(preset) }
                        .tint(selectedMinutes == preset ? theme.accent : theme.secondary)
                }
            }
            HStack {
                TextField(l.timerMinutesLabel, text: $minutes)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .accessibilityIdentifier("focus-duration-minutes")
                    .onSubmit(start)
                Text(l.timerMinutesLabel).foregroundStyle(theme.secondary)
            }
            Text(l.timerMinuteRange(SessionXP.minMinutes, SessionXP.maxMinutes))
                .font(.system(size: 11)).foregroundStyle(theme.secondary)
            HStack {
                Button(l.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(l.startFocus, action: start)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedMinutes == nil)
                    .accessibilityIdentifier("focus-duration-start")
            }
        }
        .font(.system(size: 12)).foregroundStyle(theme.text)
        .padding(14).frame(width: 280)
        .background(theme.canvas)
        .task {
            minutes = String(initialMinutes)
            NSApp.activate(ignoringOtherApps: true)
            if onStartTask != nil { titleFocused = true } else { inputFocused = true }
        }
    }

    private func start() {
        guard let selectedMinutes else { return }
        dismiss()
        if let onStartTask { onStartTask(taskTitle, taskDescription, selectedMinutes) }
        else { onStart(selectedMinutes) }
    }
}
