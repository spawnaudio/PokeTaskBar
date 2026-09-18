import AppKit
import SwiftUI

/// Geometry is shared by the native panel, drag rail, and SwiftUI content.
enum FloatingTimerMetrics {
    static let height: CGFloat = 42
    static let defaultWidth: CGFloat = 384
    static let minimumWidth: CGFloat = 288
    static let maximumWidth: CGFloat = 720
    static let widthKey = "floatingTimerWidth"

    static func width(_ proposed: CGFloat, available: CGFloat = maximumWidth) -> CGFloat {
        let proposed = proposed.isFinite ? proposed : defaultWidth
        return min(maximumWidth, max(minimumWidth, available), max(minimumWidth, proposed))
    }

    static func constrained(_ frame: NSRect, to visible: NSRect) -> NSRect {
        var result = frame
        result.origin.x = min(max(visible.minX, frame.minX), max(visible.minX, visible.maxX - frame.width))
        result.origin.y = min(max(visible.minY, frame.minY), max(visible.minY, visible.maxY - frame.height))
        return result
    }
}

@MainActor
struct FloatingTimerStrip: View {
    var onResizeTimer: (CGFloat, NSPoint) -> Void = { _, _ in }
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State var hovering = false
    @State private var handleFocused = false
    @State private var showActions = false
    @State private var addingTime = false
    @State private var completing = false
    @FocusState private var focusedControl: Control?
    private enum Control { case pause, add, done, more }

    private var l: L { companion.l }
    private var theme: MenuBarTheme { MenuBarTheme(scheme: scheme) }
    private var revealsControls: Bool { hovering || handleFocused || focusedControl != nil || voiceOver || showActions }

    var body: some View {
        if let current = session.session {
            let paused = current.userPaused || current.phase == .paused
            HStack(spacing: 5) {
                dragHandle(.resize, label: l.resizeFloatingTimer)
                    .frame(width: 12, height: 30)
                    .overlay {
                        Capsule().fill(revealsControls ? theme.accent.opacity(0.6) : theme.border)
                            .frame(width: 2, height: 16)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                FloatingTimerClock()
                    .frame(width: 74, alignment: .leading)
                Rectangle().fill(theme.border).frame(width: 1, height: 16).accessibilityHidden(true)
                HStack(spacing: 5) {
                    if !current.issue.isPomodoro, !revealsControls || store.floatingTimerWidth >= 400 {
                        LinearIssueIDButton(identifier: current.issue.identifier, url: current.issue.url)
                            .font(.system(size: 11)).foregroundStyle(theme.secondary)
                            .fixedSize()
                    }
                    Text(current.issue.title).font(.system(size: 11))
                        .foregroundStyle(theme.text).lineLimit(1).truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                controls(current: current, paused: paused)
                    .frame(width: revealsControls ? 98 : 0, alignment: .trailing)
                    .opacity(revealsControls ? 1 : 0)
                    .clipped().allowsHitTesting(revealsControls)
                FloatingTimerNewIssueButton()
                dragHandle(.move, label: l.moveFloatingTimer)
                    .frame(width: 16, height: 30)
                    .overlay {
                        Image(systemName: "circle.grid.2x2.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.secondary.opacity(revealsControls ? 1 : 0.55))
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
            }
            .padding(.horizontal, 4)
            .frame(width: CGFloat(store.floatingTimerWidth), height: FloatingTimerMetrics.height)
            .background(theme.canvas, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(
                    contrast == .increased ? theme.secondary : theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    Capsule().fill(theme.border)
                        .overlay(alignment: .leading) {
                            Capsule().fill(theme.accent)
                                .frame(width: geometry.size.width * session.plannedProgress)
                        }
                }
                .frame(height: 2).padding(.horizontal, 9)
                .accessibilityHidden(true).allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: revealsControls)
            .onChange(of: session.isComposingNote) { _, open in if open { showActions = false } }
            .onChange(of: session.resetPrompt) { _, open in if open { showActions = false } }
            .onChange(of: session.forfeitPrompt) { _, prompt in if prompt != nil { showActions = false } }
        }
    }

    private func dragHandle(_ mode: FloatingTimerDragView.Mode, label: String) -> some View {
        FloatingTimerDragHandle(mode: mode, width: CGFloat(store.floatingTimerWidth), label: label,
                                onResize: onResizeTimer, onFocusChange: { handleFocused = $0 })
            .help(label)
    }

    private func controls(current: FocusSession, paused: Bool) -> some View {
        HStack(spacing: 2) {
            Button { session.togglePause() } label: {
                Image(systemName: paused ? "play" : "pause")
            }
            .buttonStyle(FloatingTimerButtonStyle(selected: paused))
            .focused($focusedControl, equals: .pause)
            .disabled(current.phase == .awaitingChoice)
            .help(paused ? l.resumeTimer : l.pauseTimer)
            .accessibilityLabel(paused ? l.resumeTimer : l.pauseTimer)

            Button {
                session.addRemainingMinutes(5)
                addingTime = true
            } label: { Text("+5").font(.system(size: 11, weight: .medium)) }
            .buttonStyle(FloatingTimerButtonStyle(selected: addingTime))
            .focused($focusedControl, equals: .add)
            .disabled(!session.canAddRemainingTime)
            .help(l.addTimeMinutes(5)).accessibilityLabel(l.addTimeMinutes(5))
            .task(id: addingTime) {
                guard addingTime else { return }
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                addingTime = false
            }

            Button {
                if current.issue.isPomodoro { session.finishLeavingInProgress() }
                else {
                    completing = true
                    Task { await session.markIssueDone(); completing = false }
                }
            } label: { Image(systemName: "checkmark") }
            .buttonStyle(FloatingTimerButtonStyle())
            .focused($focusedControl, equals: .done)
            .disabled(completing || store.updatingLinearIssueID != nil || !canComplete(current))
            .help(current.issue.isPomodoro ? l.finishFocusTimer : l.markDone)
            .accessibilityLabel(current.issue.isPomodoro ? l.finishFocusTimer : l.markDone)

            Button { showActions.toggle() } label: { Image(systemName: "ellipsis") }
                .buttonStyle(FloatingTimerButtonStyle(selected: showActions))
                .focused($focusedControl, equals: .more)
                .help(l.floatingTimerActions).accessibilityLabel(l.floatingTimerActions)
                .popover(isPresented: $showActions, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        if !current.issue.isPomodoro {
                            let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
                            HStack {
                                LinearIssueStatusPicker(issue: issue)
                                Spacer()
                                NewLinearIssueButton()
                                SessionNoteButton()
                            }
                        }
                        FocusTimerControls()
                        Button { showActions = false; session.openDesk() } label: {
                            Label(l.todayDeskMenuOpen, systemImage: "macwindow")
                        }
                        .buttonStyle(.plain).font(.system(size: 12))
                    }
                    .padding(12).frame(width: 272)
                    .foregroundStyle(theme.text).background(theme.canvas)
                    .environment(\.menuBarChrome, true)
                }
        }
        .font(.system(size: 12, weight: .regular))
    }

    private func canComplete(_ current: FocusSession) -> Bool {
        if current.issue.isPomodoro { return true }
        let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
        return current.issue.completedStateId != nil || issue.completedStateId != nil
            || issue.teamStates.contains { $0.type.lowercased() == "completed" }
    }
}

struct FloatingTimerButtonStyle: ButtonStyle {
    var selected = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let theme = MenuBarTheme(scheme: scheme)
        configuration.label
            .frame(width: 23, height: 26)
            .foregroundStyle(selected ? theme.accent : (hovering ? theme.text : theme.secondary))
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(selected ? theme.accent.opacity(scheme == .dark ? 0.14 : 0.10)
                          : configuration.isPressed ? theme.border
                          : hovering ? theme.selected : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Uses the shared issue composer without replacing or pausing the current timer.
@MainActor
struct FloatingTimerNewIssueButton: View {
    @Environment(UsageStore.self) private var store
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Button { session.openComposer() } label: {
            Image(systemName: "plus").font(.system(size: 11))
        }
        .buttonStyle(FloatingTimerButtonStyle())
        .disabled(!store.canComposeLinearIssue)
        .help(store.canComposeLinearIssue ? companion.l.newLinearIssue : companion.l.linearIssuesNeedsSetup)
        .accessibilityLabel(companion.l.newLinearIssue)
        .accessibilityIdentifier("floating-timer-new-issue")
    }
}
