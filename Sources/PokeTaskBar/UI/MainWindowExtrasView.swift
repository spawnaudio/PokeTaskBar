import SwiftUI

@MainActor
struct MainWindowExtrasView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(MainWindowNavigation.self) private var nav
    private var l: L { companion.l }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if nav.page == .settings {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Make it yours").font(.system(size: 17, weight: .semibold))
                        Text("Preferences apply immediately. Connection credentials have their own Save action.")
                        Text("Your representative changes the displayed Pokémon. Your training partner and progress stay separate.")
                            .foregroundStyle(.secondary)
                        Button("Choose in Collection →") {
                            nav.content.openRepresentativeDex(); nav.select(.collection)
                        }.buttonStyle(.link)
                    }.mainWindowCard()
                } else {
                if nav.page == .focus { inspector }
                todayLog
                VStack(alignment: .leading, spacing: 12) {
                    Text(l.usageTab).font(.system(size: 17, weight: .semibold))
                    Text(TokenFormatter.compact(store.todayTotalTokens))
                        .font(.system(size: 28, weight: .semibold)).monospacedDigit()
                    Text("Tokens today").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button { nav.select(.usage) } label: {
                        HStack { Text("View usage"); Spacer(); Image(systemName: "arrow.right") }
                    }.buttonStyle(.plain)
                }.mainWindowCard()
                if nav.page == .focus {
                    MainWindowCompanionHero(size: 100).mainWindowCard()
                }
                }
            }
        }.scrollIndicators(.hidden)
    }
    private var inspector: some View {
        let issue: LinearIssueSummary? = {
            guard let current = session.session, !current.issue.isPomodoro else { return nil }
            return store.linearIssue(id: current.issue.id) ?? current.issue.summary
        }()
        return VStack(alignment: .leading, spacing: 8) {
            PopoverSectionLabel(text: l.todayDeskDetailsSection)
            if let issue {
                let rows = LinearIssueInspector.fields(for: issue)
                if rows.isEmpty {
                    Text(l.todayDeskInspectorEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, field in
                        inspectorRow(field, issue: issue)
                    }
                    if let text = issue.descriptionText, !text.isEmpty {
                        LinearMarkdownText(source: text)
                    }
                }
            } else {
                Text(l.todayDeskInspectorEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mainWindowCard()
    }

    private func inspectorRow(_ field: LinearIssueInspector.Field, issue: LinearIssueSummary) -> some View {
        LinearPropertyRow(label: inspectorLabel(field.kind)) {
            HStack(spacing: 6) {
                if field.kind == .status {
                    LinearStatusDot(type: field.stateType)
                }
                if field.kind == .team {
                    LinearTagChip(
                        text: field.value,
                        tint: LinearTeamTint.color(forKey: issue.teamKey, name: issue.teamName))
                } else if field.kind == .project {
                    LinearTagChip(text: field.value, tint: LinearChromeTint.project)
                } else {
                    Text(field.value)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func inspectorLabel(_ kind: LinearIssueInspector.Kind) -> String {
        switch kind {
        case .status: return l.linearStatusUnknown
        case .team: return l.todayDeskTeamLabel
        case .project: return l.todayDeskProjectLabel
        case .assignee: return l.todayDeskAssigneeLabel
        case .labels: return l.todayDeskLabelsLabel
        case .estimate: return l.todayDeskEstimateLabel
        case .due: return l.todayDeskDueLabel
        }
    }

    private var todayLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(l.todayDeskLogTitle).font(.system(size: 17, weight: .semibold))
                Spacer()
                if session.todayDriftCount > 0 {
                Text(l.driftCountLabel(session.todayDriftCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            let entries = session.todayLog
            if entries.isEmpty {
                Text(l.todayDeskLogEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entries) { entry in
                            logRow(entry)
                        }
                    }
                }.frame(maxHeight: 280)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .mainWindowCard()
    }

    private func logRow(_ entry: FocusLogEntry) -> some View {
        Group {
            switch entry.kind {
            case .session:
                let duration = FocusClock.format(entry.durationSeconds ?? 0)
                let ot = (entry.overtimeSeconds ?? 0) > 0 ? FocusClock.format(entry.overtimeSeconds ?? 0) : ""
                Text(l.sessionLogLine(identifier: entry.issueIdentifier, duration: duration, overtime: ot))
            case .checkIn:
                let answer: String = {
                    switch entry.checkInAnswer {
                    case .yes: return l.checkInYes
                    case .no: return l.checkInNo
                    case .skip: return l.checkInSkip
                    case nil: return ""
                    }
                }()
                Text(l.checkInLogLine(
                    identifier: entry.issueIdentifier,
                    answer: answer,
                    notePosted: entry.notePosted))
            case .note:
                Text(l.sessionNoteLogLine(
                    identifier: entry.issueIdentifier,
                    note: entry.noteText ?? ""))
            case .forfeit:
                Text(l.forfeitLogLine(
                    identifier: entry.issueIdentifier,
                    xp: TokenFormatter.compact(entry.xpDelta ?? 0)))
            }
        }
        .font(.caption)
        .foregroundStyle(entry.usesDestructiveTint ? Color.red : Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
