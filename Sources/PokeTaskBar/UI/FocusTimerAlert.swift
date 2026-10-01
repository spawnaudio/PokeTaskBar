import AppKit
import Observation
import SwiftUI

/// A native alarm surface that also works when notifications or the floating pet are off.
@MainActor
final class FocusTimerAlertController: NSObject, NSWindowDelegate {
    private let usage: UsageStore
    private let companion: CompanionStore
    private let session: FocusSessionStore
    private var panel: NSPanel?
    private var presented = false
    private let sound = NSSound(named: NSSound.Name("Glass"))
    var isSoundPlaying: Bool { sound?.isPlaying == true }

    init(usage: UsageStore, companion: CompanionStore, session: FocusSessionStore) {
        self.usage = usage
        self.companion = companion
        self.session = session
        super.init()
        sound?.loops = true
        observe()
    }

    private func observe() {
        withObservationTracking {
            sync()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func sync() {
        let awaiting = session.session?.phase == .awaitingChoice
        let ringing = session.timerAlarmRinging && usage.timerAlarmSoundEnabled
        if ringing {
            if sound?.isPlaying != true { sound?.play() }
        } else { sound?.stop() }

        guard awaiting else {
            panel?.orderOut(nil)
            panel?.contentView = nil
            presented = false
            return
        }
        guard !presented, session.session?.sleepHeld == false else { return }
        presented = true
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 330),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.identifier = NSUserInterfaceItemIdentifier("PokeTaskBar.FocusTimerAlert")
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.delegate = self
            panel.center()
            self.panel = panel
        }
        panel?.title = companion.l.timesUpFlashTitle
        panel?.contentView = NSHostingView(rootView: FocusTimerAlertView()
            .environment(usage).environment(companion).environment(session))
        panel?.orderFrontRegardless()
        NSApp.requestUserAttention(.informationalRequest)
    }

    func windowWillClose(_ notification: Notification) {
        session.silenceTimerAlarm()
        sound?.stop()
        panel?.contentView = nil
    }
}

@MainActor
struct FocusTimerAlertView: View {
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label(companion.l.timesUpFlashTitle, systemImage: "alarm.fill")
                    .font(.title2.weight(.semibold))
                if let current = session.session {
                    Text(current.issue.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    if let description = current.issue.taskDescription {
                        Text(description).foregroundStyle(.secondary)
                    }
                }
                SessionPromptCard()
                Button(companion.l.addTimeMinutes(5)) { session.addRemainingMinutes(5) }
                    .tahoeButtonStyle(.regular).disabled(!session.canAddRemainingTime)
                if session.timerAlarmSilenced {
                    Text(companion.l.timerAlarmSilenced).font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
