import SwiftUI

@MainActor
struct MainWindowFocusView: View {
    @Environment(UsageStore.self) private var usage
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(MainWindowNavigation.self) private var nav
    @State private var choosingTimer = false
    private var l: L { companion.l }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let current = session.session {
                    let issue = usage.linearIssue(id: current.issue.id) ?? current.issue.summary
                    VStack(spacing: 10) {
                        if !current.issue.isPomodoro {
                            LinearIssueIDButton(identifier: current.issue.identifier, url: current.issue.url)
                        }
                        Text(current.issue.title).font(.system(size: 24, weight: .semibold))
                            .multilineTextAlignment(.center)
                        if !current.issue.isPomodoro {
                            HStack(spacing: 12) {
                                LinearIssueStatusPicker(issue: issue)
                                if let project = issue.projectName { Text(project).foregroundStyle(.secondary) }
                            }
                        }
                    }.padding(.top, 30)
                    Text(session.clockDisplay().text)
                        .font(.system(size: 88, weight: .medium).monospacedDigit())
                        .minimumScaleFactor(0.55).lineLimit(1)
                        .contentTransition(.identity).padding(.top, 20)
                    VStack(spacing: 12) {
                        Text(l.plannedDurationLine(l.minutesValue(Int(current.plannedSeconds / 60))))
                            .foregroundStyle(.secondary)
                        ProgressView(value: session.plannedProgress).tint(.blue)
                    }.frame(maxWidth: 420)
                    HStack(spacing: 12) {
                        FocusPauseButton(paused: current.userPaused || current.phase == .paused,
                            disabled: current.phase == .awaitingChoice, pauseTitle: l.pauseTimer,
                            resumeTitle: l.resumeTimer) { session.togglePause() }
                        if current.issue.isPomodoro {
                            Button(l.finishFocusTimer) { session.finishLeavingInProgress() }.tahoeButtonStyle(.prominent)
                        } else {
                            FocusMarkDoneButton(title: l.markDone,
                                disabled: usage.updatingLinearIssueID != nil || !usage.canComposeLinearIssue ||
                                    (issue.completedStateId == nil && !issue.teamStates.contains { $0.type.lowercased() == "completed" })) {
                                Task { await session.markIssueDone() }
                            }
                        }
                    }.controlSize(.large)
                    FocusTimerControls(compact: false).frame(maxWidth: 460)
                    if !current.issue.isPomodoro {
                        VStack(alignment: .leading, spacing: 12) {
                            SessionNoteButton(compact: false)
                            if session.isComposingNote { SessionNoteComposer(compact: false) }
                            if session.notePostFailed { Text(l.linearCommentFailed).foregroundStyle(.orange) }
                        }.frame(maxWidth: .infinity, alignment: .leading).mainWindowCard()
                    }
                } else {
                    Image(systemName: "target").font(.system(size: 42)).foregroundStyle(.secondary).padding(.top, 60)
                    Text(l.focusIssueOrTimerPrompt).font(.system(size: 24, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Button(l.linearIssuesTab) { nav.select(.issues) }.tahoeButtonStyle(.prominent)
                    Button(l.pomoTimer) { choosingTimer = true }.tahoeButtonStyle(.regular)
                        .popover(isPresented: $choosingTimer) {
                            FocusDurationPicker(issueTitle: l.pomodoroTitle, initialMinutes: session.plannedMinutes) { minutes in
                                session.plannedMinutes = minutes
                                session.startPomodoro()
                                choosingTimer = false
                            }
                        }
                }
                if let warning = session.forfeitPrompt {
                    FocusForfeitWarningCard(warning: warning)
                } else if session.resetPrompt {
                    FocusResetConfirmCard()
                } else { SessionPromptCard() }
                if usage.linearIssuesError != nil { Text(l.linearIssuesSyncFailed).foregroundStyle(.orange) }
            }.frame(maxWidth: .infinity).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
    }
}
