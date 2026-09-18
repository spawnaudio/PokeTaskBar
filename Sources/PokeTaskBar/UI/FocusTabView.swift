import AppKit
import SwiftUI

/// Compact companion and focus workspace. Existing prompts and timer actions
/// stay connected to FocusSessionStore; the footer belongs to the window shell.
@MainActor
struct FocusTabView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(PopoverNavigation.self) private var nav
    @Environment(\.colorScheme) private var scheme
    @State private var showTimeXP = false

    private var l: L { companion.l }
    private var theme: MenuBarTheme { MenuBarTheme(scheme: scheme) }

    var body: some View {
        ContentFittingScrollView {
            VStack(alignment: .leading, spacing: 8) {
                promptStack
                CompanionHeader(store: companion)
                ScoreBoard(store: companion, compact: true)
                MenuBarDivider()
                focusSessionSection
                MenuBarDivider()
                pomodoroRow
                DisclosureGroup(isExpanded: $showTimeXP) {
                    TimeXPView(store: store, companion: companion, compact: true)
                        .popoverCard()
                        .padding(.top, 8)
                } label: {
                    Text(l.timeXPTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var focusSessionSection: some View {
        if let current = session.session {
            runningFocus(current)
        } else {
            idleFocusPrompt
        }
    }

    @ViewBuilder
    private var promptStack: some View {
        if let warning = session.forfeitPrompt {
            FocusForfeitWarningCard(warning: warning)
        } else if session.resetPrompt {
            FocusResetConfirmCard()
        } else if SessionPromptSurface.showsOnPopover(floatingPetEnabled: store.floatingPetEnabled),
                  session.prompt != .none
                    || SessionPromptSurface.showsPopoverCaption(
                        floatingPetEnabled: store.floatingPetEnabled,
                        prompt: session.prompt,
                        bubbleIsCritical: store.currentSpeechBubble?.isCritical == true) {
            PopoverSessionBanner()
        }
    }

    private func runningFocus(_ current: FocusSession) -> some View {
        let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
        let clock = session.clockDisplay()
        let paused = current.userPaused || current.phase == .paused
        let canMarkDone = issue.completedStateId != nil
            || issue.teamStates.contains { $0.type.lowercased() == "completed" }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(l.currentFocus, systemImage: paused ? "pause.circle" : "target")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
                Spacer()
                if let url = current.issue.url, !current.issue.isPomodoro {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "arrow.up.right.square")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondary)
                    .help(l.linearOpenIssue)
                    .accessibilityLabel(l.linearOpenIssue)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                if !current.issue.isPomodoro {
                    LinearIssueIDButton(identifier: current.issue.identifier, url: current.issue.url)
                }
                Text(current.issue.title)
                    .font(.system(size: 18, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            if !current.issue.isPomodoro {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        LinearIssueStatusPicker(issue: issue, compact: true)
                        if let project = issue.projectName {
                            Label(project, systemImage: "hexagon")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.secondary)
                                .lineLimit(1)
                        }
                    }
                    LinearIssueStatusPicker(issue: issue, compact: true)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(clock.text)
                        .font(.system(size: 50, weight: .semibold).monospacedDigit())
                        .contentTransition(.identity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if clock.overtime {
                        Text(l.overtimeAbbrev)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(clock.overtime ? l.plannedDurationLine(l.minutesValue(Int(current.plannedSeconds / 60)))
                     : l.focusTimeRemaining(Int(current.plannedSeconds / 60)))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
                ProgressView(value: session.plannedProgress)
                    .progressViewStyle(MenuBarProgressStyle(tint: clock.overtime ? .orange : theme.accent))
                    .tint(clock.overtime ? .orange : theme.accent)
                    .controlSize(.small)
                    .padding(.top, 6)
                    .accessibilityLabel(l.plannedLengthLabel)
            }
            HStack(spacing: 8) {
                Button { session.togglePause() } label: {
                    Label(paused ? l.resumeTimer : l.pauseTimer,
                          systemImage: paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MenuBarButtonStyle())
                .disabled(current.phase == .awaitingChoice)
                if current.issue.isPomodoro {
                    Button { session.finishLeavingInProgress() } label: {
                        Label(l.finishFocusTimer, systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MenuBarButtonStyle(prominent: true))
                } else {
                    Button { Task { await session.markIssueDone() } } label: {
                        Label(l.markDone, systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MenuBarButtonStyle(prominent: true))
                    .disabled(!canMarkDone || store.updatingLinearIssueID != nil || !store.canComposeLinearIssue)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            FocusTimerControls(menuBarLayout: true)
            if store.linearIssuesError != nil {
                Text(l.linearIssuesSyncFailed).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var idleFocusPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(l.currentFocus, systemImage: "target")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondary)
            Text(l.focusIssueOrTimerPrompt)
                .font(.system(size: 21, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Button { nav.tab = .linear } label: {
                Label(l.openLinearTab, systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MenuBarButtonStyle(prominent: true))
        }
        .padding(.vertical, 8)
    }

    private var pomodoroRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer").foregroundStyle(theme.secondary)
            Text(l.pomoTimer).font(.system(size: 13, weight: .medium))
            Spacer(minLength: 4)
            Text(l.minutesValue(session.plannedMinutes))
                .font(.system(size: 12)).foregroundStyle(theme.secondary)
            Button { session.openPomodoroSetup() } label: {
                Image(systemName: "play.fill")
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(MenuBarButtonStyle())
            .disabled(session.isActive)
            .help(l.pomoTimer)
            .accessibilityLabel(l.pomoTimer)
        }
    }
}
