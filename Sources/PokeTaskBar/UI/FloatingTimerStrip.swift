import AppKit
import SwiftUI

/// Geometry is shared by the native panel, drag rail, and SwiftUI content.
enum FloatingTimerMetrics {
    static let height: CGFloat = 42
    static let defaultWidth: CGFloat = 384
    static let minimumWidth: CGFloat = 288
    static let maximumWidth: CGFloat = 720
    static let widthKey = "floatingTimerWidth"
    static let scaleKey = "floatingTimerScale"
    static let scaleRange: ClosedRange<Double> = 0.5...2

    static func scale(_ proposed: Double) -> Double {
        proposed.isFinite ? min(scaleRange.upperBound, max(scaleRange.lowerBound, proposed)) : 1
    }

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

extension View {
    func scaledFloatingTimer(size: NSSize, scale: CGFloat) -> some View {
        frame(width: size.width, height: size.height, alignment: .bottomTrailing)
            .scaleEffect(scale, anchor: .bottomTrailing)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .bottomTrailing)
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
    @State private var pointerInside = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var handleFocused = false
    @State private var showActions = false
    @State private var completing = false
    @FocusState private var focusedControl: Control?
    private enum Control { case pause, note, done, more }

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
                        Capsule().fill(theme.accent.opacity(revealsControls ? 0.6 : 0))
                            .frame(width: 2, height: 16)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                FloatingTimerClock()
                    .frame(width: 74, alignment: .leading)
                Rectangle().fill(theme.border).frame(width: 1, height: 16).accessibilityHidden(true)
                ZStack(alignment: .leading) {
                    Text(current.issue.title).font(.system(size: 13))
                        .foregroundStyle(theme.text).lineLimit(1).truncationMode(.tail)
                        .opacity(revealsControls ? 0 : 1)
                    HStack(spacing: 4) {
                        ViewThatFits(in: .horizontal) {
                            controls(current: current, paused: paused, labeled: true).fixedSize()
                            controls(current: current, paused: paused, labeled: false).fixedSize()
                        }
                        dragHandle(.move, label: l.moveFloatingTimer)
                            .frame(width: 12, height: 30)
                            .overlay {
                                Image(systemName: store.floatingTimerDetached && store.floatingTimerPinned
                                      ? "pin.fill" : "circle.grid.2x2.fill")
                                    .font(.system(size: 9)).foregroundStyle(theme.secondary)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                            }
                    }
                    .opacity(revealsControls ? 1 : 0).allowsHitTesting(revealsControls)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
            .frame(width: CGFloat(store.floatingTimerWidth), height: FloatingTimerMetrics.height)
            .background(theme.canvas, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    contrast == .increased ? theme.secondary : theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .background(FloatingTimerHoverArea(onHover: pointerChanged))
            .onKeyPress(phases: .down) { _ in
                keepKeyboardControlsVisible()
                return .ignored
            }
            .onChange(of: focusedControl) { _, control in
                if control != nil, NSApp.currentEvent?.type == .keyDown { keepKeyboardControlsVisible() }
            }
            .onChange(of: showActions) { _, open in
                if !open, !pointerInside { pointerChanged(false) }
            }
            .onDisappear { hideControlsTask?.cancel() }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: revealsControls)
            .onChange(of: session.isComposingNote) { _, open in if open { showActions = false } }
            .onChange(of: session.resetPrompt) { _, open in if open { showActions = false } }
            .onChange(of: session.forfeitPrompt) { _, prompt in if prompt != nil { showActions = false } }
        }
    }

    private func pointerChanged(_ inside: Bool) {
        pointerInside = inside
        hideControlsTask?.cancel()
        if inside { hovering = true; return }
        hideControlsTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            // Mouse clicks can leave SwiftUI or a native drag handle focused after exit.
            focusedControl = nil
            handleFocused = false
            hovering = false
        }
    }

    private func keepKeyboardControlsVisible() {
        hideControlsTask?.cancel()
        hovering = pointerInside
    }

    private func dragHandle(_ mode: FloatingTimerDragView.Mode, label: String) -> some View {
        FloatingTimerDragHandle(mode: mode, width: CGFloat(store.floatingTimerWidth), label: label,
                                scale: CGFloat(store.floatingTimerScale),
                                movementLocked: mode == .move && store.floatingTimerDetached && store.floatingTimerPinned,
                                onResize: onResizeTimer, onFocusChange: {
                                    handleFocused = $0
                                    if $0 { keepKeyboardControlsVisible() }
                                })
            .help(label)
    }

    private func controls(current: FocusSession, paused: Bool, labeled: Bool) -> some View {
        HStack(spacing: 5) {
            Button { session.togglePause() } label: {
                Image(systemName: paused ? "play" : "pause")
            }
            .buttonStyle(FloatingTimerButtonStyle(selected: paused, width: 28, filled: true))
            .focused($focusedControl, equals: .pause)
            .disabled(current.phase == .awaitingChoice)
            .help(paused ? l.resumeTimer : l.pauseTimer)
            .accessibilityLabel(paused ? l.resumeTimer : l.pauseTimer)

            Button { session.toggleNoteComposer() } label: {
                HStack(spacing: 5) { Image(systemName: "doc.text"); if labeled { Text("Notes") } }
            }
                .buttonStyle(FloatingTimerButtonStyle(width: labeled ? 67 : 28, filled: true))
                .focused($focusedControl, equals: .note)
                .disabled(current.issue.isLocal)
                .help(l.sessionNoteHelp).accessibilityLabel(l.checkInAddNote)

            Button {
                if current.issue.isLocal { session.finishLeavingInProgress() }
                else {
                    completing = true
                    Task { await session.markIssueDone(); completing = false }
                }
            } label: {
                HStack(spacing: 5) { Image(systemName: "checkmark.circle"); if labeled { Text("Complete") } }
            }
            .buttonStyle(FloatingTimerButtonStyle(width: labeled ? 86 : 28, filled: true))
            .focused($focusedControl, equals: .done)
            .disabled(completing || store.updatingLinearIssueID != nil || !canComplete(current))
            .help(current.issue.isLocal ? l.finishFocusTimer : l.markDone)
            .accessibilityLabel(current.issue.isLocal ? l.finishFocusTimer : l.markDone)

            Button { showActions.toggle() } label: { Image(systemName: "ellipsis") }
                .buttonStyle(FloatingTimerButtonStyle(selected: showActions, width: 28, filled: true))
                .focused($focusedControl, equals: .more)
                .accessibilityIdentifier("floating-timer-more")
                .help(l.floatingTimerActions).accessibilityLabel(l.floatingTimerActions)
                .popover(isPresented: $showActions, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if !current.issue.isLocal {
                                let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
                                LinearIssueStatusPicker(issue: issue)
                            } else {
                                Text(current.issue.title).font(.system(size: 12)).lineLimit(1)
                            }
                            Spacer()
                            NewLinearIssueButton(beforeOpen: { showActions = false })
                                .accessibilityIdentifier("floating-timer-menu-new-issue")
                            if !current.issue.isLocal {
                                SessionNoteButton()
                            }
                        }
                        FocusTimerControls()
                        Button {
                            showActions = false
                            store.floatingTimerDetached.toggle()
                            store.floatingPetIslandFolded = false
                        } label: {
                            Label(store.floatingTimerDetached ? l.attachFloatingTimer : l.detachFloatingTimer,
                                  systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.plain).font(.system(size: 12))
                        if store.floatingTimerDetached {
                            @Bindable var store = store
                            Toggle(l.pinFloatingTimer, isOn: $store.floatingTimerPinned)
                                .toggleStyle(.switch).controlSize(.small)
                        }
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
        if current.issue.isLocal { return true }
        let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
        return current.issue.completedStateId != nil || issue.completedStateId != nil
            || issue.teamStates.contains { $0.type.lowercased() == "completed" }
    }
}

/// Track exits even when an always-on-top timer is not the key window.
private struct FloatingTimerHoverArea: NSViewRepresentable {
    var onHover: (Bool) -> Void
    func makeNSView(context: Context) -> FloatingTimerHoverView { FloatingTimerHoverView() }
    func updateNSView(_ view: FloatingTimerHoverView, context: Context) { view.onHover = onHover }
}

final class FloatingTimerHoverView: NSView {
    var onHover: (Bool) -> Void = { _ in }
    private var hoverArea: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }
}

struct FloatingTimerButtonStyle: ButtonStyle {
    var selected = false
    var width: CGFloat = 23
    var filled = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let theme = MenuBarTheme(scheme: scheme)
        configuration.label
            .frame(width: width, height: filled ? 28 : 26)
            .foregroundStyle(selected ? theme.accent : (filled || hovering ? theme.text : theme.secondary))
            .background {
                RoundedRectangle(cornerRadius: filled ? 8 : 5)
                    .fill(selected ? theme.accent.opacity(scheme == .dark ? 0.14 : 0.10)
                          : configuration.isPressed ? theme.border
                          : hovering || filled ? theme.selected : Color.clear)
                    .overlay {
                        if filled { RoundedRectangle(cornerRadius: 8).strokeBorder(theme.border.opacity(0.7), lineWidth: 1) }
                    }
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
