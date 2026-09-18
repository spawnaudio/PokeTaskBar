import AppKit
import SwiftUI

/// Dual-sidebar Today window. Closing it does not stop a running session.
@MainActor
final class TodayDeskController: NSObject, NSWindowDelegate {
    private let usage: UsageStore
    private let companion: CompanionStore
    private let session: FocusSessionStore
    private var window: NSWindow?
    private let navigation = MainWindowNavigation()
    private let updater: UpdateChecker

    init(usage: UsageStore, companion: CompanionStore, session: FocusSessionStore, updater: UpdateChecker) {
        self.usage = usage
        self.companion = companion
        self.session = session
        self.updater = updater
        super.init()
        session.onOpenDesk = { [weak self] in
            self?.navigation.select(.focus)
            self?.open()
        }
    }

    func open() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            window = makeWindow()
        } else if window?.contentView == nil {
            window?.contentView = hostedView()
            window?.title = L(companion.language).todayDeskWindowTitle
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func hostedView() -> NSView {
        NSHostingView(rootView:
            MainWindowView()
                .environment(navigation)
                .environment(updater)
                .environment(usage)
                .environment(companion)
                .environment(session)
                .environment(\.locale, companion.language.displayLocale)
                .ignoresSafeArea(.container, edges: .top)
        )
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: TodayDeskMetrics.defaultWidth,
                height: TodayDeskMetrics.defaultHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "PokeTaskBar"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.identifier = NSUserInterfaceItemIdentifier(LaunchWindowPolicy.todayDeskIdentifier)
        // Frame only. Sidebar widths/collapse are UsageStore keys (`todayDeskLeftWidth` etc.).
        window.setFrameAutosaveName(LaunchWindowPolicy.todayDeskAutosaveName)
        window.contentMinSize = NSSize(
            width: TodayDeskMetrics.minWidth,
            height: TodayDeskMetrics.minHeight)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = hostedView()
        if window.frame.origin == .zero { window.center() }
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Keep the session on the overlay; only hide the desk.
        window?.contentView = nil
    }
}

@MainActor
struct SessionPromptCard: View {
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }
    @FocusState private var checkInFieldFocused: Bool

    var body: some View {
        switch session.prompt {
        case .none:
            EmptyView()
        case .zeroTime:
            zeroTime
        case .checkIn:
            checkIn
        }
    }

    private var zeroTime: some View {
        let id = session.session?.issue.identifier ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(l.timesUpPopupTitle(id))
                .font(.callout.weight(.semibold))
            Button(l.timesUpContinue) { session.continueOvertime() }
                .tahoeButtonStyle(.prominent)
            Button(l.timesUpFinishLeave) { session.finishLeavingInProgress() }
                .tahoeButtonStyle(.regular)
            Button(l.timesUpMarkDone) { Task { await session.markIssueDone() } }
                .tahoeButtonStyle(.regular)
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .tahoePromptChrome()
    }

    private var checkIn: some View {
        @Bindable var session = session
        let id = session.session?.issue.identifier ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(l.stillOnIssue(id))
                .font(.callout.weight(.semibold))
            TextField(l.checkInNotePlaceholder, text: $session.checkInDraft)
                .textFieldStyle(.roundedBorder)
                .focused($checkInFieldFocused)
            HStack {
                Button(l.checkInYes) { Task { await session.answerCheckIn(.yes) } }
                    .tahoeButtonStyle(.prominent)
                Button(l.checkInNo) { Task { await session.answerCheckIn(.no) } }
                    .tahoeButtonStyle(.regular)
                Button(l.checkInSkip) { Task { await session.answerCheckIn(.skip) } }
                    .tahoeButtonStyle(.accessory)
                    .foregroundStyle(.secondary)
            }
            Text(l.checkInAddNote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .tahoePromptChrome()
        .onAppear { checkInFieldFocused = true }
    }
}

/// Pet-off host for 0:00 / check-in. Critical forfeit caption when the card isn't up.
@MainActor
struct PopoverSessionBanner: View {
    @Environment(UsageStore.self) private var store
    @Environment(FocusSessionStore.self) private var session

    var body: some View {
        if session.prompt != .none {
            SessionPromptCard()
        } else if let bubble = store.currentSpeechBubble,
                  SessionPromptSurface.showsPopoverCaption(
                    floatingPetEnabled: store.floatingPetEnabled,
                    prompt: session.prompt,
                    bubbleIsCritical: bubble.isCritical) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bubble.title)
                    .font(.caption.weight(.semibold))
                Text(bubble.body)
                    .font(.caption2)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

@MainActor
struct TodayDeskPinRow: View {
    let issue: LinearIssueSummary
    let pinned: Bool
    let onPin: (Int) -> Void
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @State private var choosingDuration = false

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            LinearStatusDot(type: issue.stateType)
            Button {
                if pinned { onPin(session.plannedMinutes) }
                else { choosingDuration = true }
            } label: {
                Text(issue.title)
                    .font(.callout.weight(pinned ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $choosingDuration, arrowEdge: .bottom) {
                FocusDurationPicker(issueTitle: issue.title, initialMinutes: session.plannedMinutes) { minutes in
                    choosingDuration = false
                    onPin(minutes)
                }
                .environment(companion)
            }
            LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            Color.primary.opacity(pinned ? 0.10 : (hovering ? 0.06 : 0)),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .onHover { hovering = $0 }
        .accessibilityAddTraits(pinned ? .isSelected : [])
    }
}

private extension Color {
    static var windowBackgroundColor: Color { Color(nsColor: .windowBackgroundColor) }
}
