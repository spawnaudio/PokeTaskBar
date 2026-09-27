import AppKit
import SwiftUI

/// Closest SF Symbols to Linear’s chrome (issue circle / project hexagon / initiative flag).
private enum LinearChromeSymbol {
    static let issue = "circle"
    static let project = "hexagon"
    static let initiative = "flag"
}

@MainActor
private enum LinearRootTab: Hashable {
    case issues
    case projects
    case initiatives
}

@MainActor
enum LinearIssuesTab: CaseIterable, Hashable {
    case inProgress
    case todo
    case planned
    case completedToday

    func title(_ l: L) -> String {
        switch self {
        case .inProgress: l.linearInProgressTab
        case .todo: l.linearTodoTab
        case .planned: l.linearPlannedTab
        case .completedToday: l.linearCompletedTab
        }
    }

    func emptyText(_ l: L) -> String {
        switch self {
        case .inProgress: l.linearIssuesEmptyInProgress
        case .todo: l.linearIssuesEmptyTodo
        case .planned: l.linearIssuesEmptyPlanned
        case .completedToday: l.linearIssuesEmptyCompleted
        }
    }

    func issues(in store: UsageStore, projectID: String? = nil) -> [LinearIssueSummary] {
        if let projectID, let project = store.linearProjects.first(where: { $0.id == projectID }) {
            switch self {
            case .inProgress:
                return project.issues.filter(LinearClient.isInProgressIssue)
            case .todo: return project.issues.filter(LinearClient.isTodoIssue)
            case .planned: return project.issues.filter(LinearClient.isPlannedIssue)
            case .completedToday:
                return project.issues.filter { $0.stateType?.lowercased() == "completed" }
            }
        }
        switch self {
        case .inProgress: return store.linearInProgressIssues
        case .todo: return store.linearTodoIssues
        case .planned: return store.linearPlannedIssues
        case .completedToday: return store.linearCompletedTodayIssues
        }
    }
}

@MainActor
struct LinearIntegrationView: View {
    let store: UsageStore
    @Environment(CompanionStore.self) private var companion
    @Environment(PopoverNavigation.self) private var nav
    @State private var selectedRoot: LinearRootTab = .issues
    @State private var selectedIssuesTab: LinearIssuesTab = .inProgress
    @State private var issueSorts: [LinearIssuesTab: LinearIssueSort] = [:]
    @State private var selectedProjectStatus = ""
    @State private var projectSort: LinearProjectSort = .name
    @State private var initiativeSort: LinearInitiativeSort = .name
    @State private var plannedInitiatives = false

    private var l: L { companion.l }

    private var visibleIssues: [LinearIssueSummary] {
        (issueSorts[selectedIssuesTab] ?? .priority).sorted(selectedIssuesTab.issues(in: store))
    }

    private var visibleProjects: [LinearProjectSummary] {
        LinearContainerOrder.pinnedFirst(projectSort.sorted(LinearProjectStatuses.matching(
            store.linearProjects, selection: selectedProjectStatus, catalog: store.linearProjectStatuses)),
            ids: store.pinnedLinearProjectIDs)
    }

    private var visibleInitiatives: [LinearInitiativeSummary] {
        LinearContainerOrder.pinnedFirst(initiativeSort.sorted(store.linearInitiatives.filter { initiative in
            plannedInitiatives ? LinearClient.matchesInitiativePlanned(name: initiative.statusName)
                : LinearClient.matchesInitiativeActive(name: initiative.statusName)
        }), ids: store.pinnedLinearInitiativeIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                NewLinearIssueButton(showsTitle: true)
                Spacer()
                if selectedRoot == .issues {
                    LinearIssueSortMenu(selection: Binding(
                        get: { issueSorts[selectedIssuesTab] ?? .priority },
                        set: { issueSorts[selectedIssuesTab] = $0 }))
                }
                if selectedRoot == .projects || selectedRoot == .initiatives {
                    LinearProjectIssueFilterMenu()
                    if selectedRoot == .projects { LinearProjectSortMenu(selection: $projectSort) }
                    else { LinearInitiativeSortMenu(selection: $initiativeSort) }
                } else {
                    LinearCardDisplayMenu()
                }
                Button {
                    Task { _ = await store.refreshLinearIssues() }
                } label: {
                    if store.isRefreshingLinearIssues {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .tahoeButtonStyle(.accessory)
                .buttonBorderShape(.circle)
                .help(l.refreshNow)
                .disabled(!store.linearIntegrationEnabled || !store.linearAPIKeyConfigured || store.isRefreshingLinearIssues)
            }

            TahoeTabBar(selection: $selectedRoot, items: [
                TahoeTabItem(.issues, title: l.linearIssuesTab, symbol: LinearChromeSymbol.issue),
                TahoeTabItem(
                    .projects, title: l.linearProjectsTab, symbol: LinearChromeSymbol.project,
                    symbolColor: LinearChromeTint.project),
                TahoeTabItem(.initiatives, title: l.linearInitiativesTab, symbol: LinearChromeSymbol.initiative),
            ])

            if !store.linearIntegrationEnabled || !store.linearAPIKeyConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.linearIssuesNeedsSetup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(l.settings) { nav.showSettings = true }
                        .tahoeButtonStyle(.regular)
                        .controlSize(.small)
                }
            } else {
                if selectedRoot == .issues {
                    TahoeTabBar(selection: $selectedIssuesTab, items: [
                        TahoeTabItem(.inProgress, title: l.linearInProgressTab, symbol: "circle"),
                        TahoeTabItem(.todo, title: l.linearTodoTab, symbol: "circle.dashed"),
                        TahoeTabItem(.planned, title: l.linearPlannedTab, symbol: "calendar"),
                        TahoeTabItem(.completedToday, title: l.linearCompletedTab, symbol: "checkmark"),
                    ])
                } else if selectedRoot == .projects {
                    LinearProjectStatusMenu(statuses: LinearProjectStatuses.options(
                        projects: store.linearProjects, catalog: store.linearProjectStatuses), selection: $selectedProjectStatus)
                } else if selectedRoot == .initiatives {
                    LinearInitiativeStatusMenu(planned: $plannedInitiatives)
                }

                if let updated = store.linearIssuesUpdatedAt {
                    HStack(spacing: 4) {
                        Text(l.linearLastSynced)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        RelativeTimestampText(date: updated)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if store.linearIssuesError != nil {
                    Text(l.linearIssuesSyncFailed)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                switch selectedRoot {
                case .issues:
                    issuesList
                case .projects:
                    let values = visibleProjects
                    let dividerID = LinearContainerOrder.dividerID(values, ids: store.pinnedLinearProjectIDs)
                    if values.isEmpty {
                        Text(l.linearProjectsNoMatches)
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ContentFittingScrollView(fillsViewport: values.count > 8) {
                            LazyVStack(spacing: 8) {
                                ForEach(values) { project in
                                    VStack(spacing: 8) {
                                        if project.id == dividerID { Divider() }
                                        LinearProjectCard(project: project, hiddenIssueStatuses: store.hiddenLinearIssueStatuses) { nav.showFocus() }
                                    }
                                }
                            }
                        }.frame(maxHeight: .infinity)
                    }
                case .initiatives:
                    initiativesList
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .task(id: store.linearIntegrationEnabled && store.linearAPIKeyConfigured) {
            guard store.linearIntegrationEnabled, store.linearAPIKeyConfigured else { return }
            _ = await store.refreshLinearIssues()
        }
    }

    @ViewBuilder
    private var issuesList: some View {
        if visibleIssues.isEmpty {
            Text(selectedIssuesTab.emptyText(l))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.top, 4)
        } else {
            ContentFittingScrollView(fillsViewport: visibleIssues.count > 8) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleIssues) { issue in
                        issueCard(issue)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var initiativesList: some View {
        Group {
            let values = visibleInitiatives
            let dividerID = LinearContainerOrder.dividerID(values, ids: store.pinnedLinearInitiativeIDs)
            if values.isEmpty {
                Text(plannedInitiatives ? l.linearInitiativesEmptyPlanned : l.linearInitiativesEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, 4)
            } else {
                ContentFittingScrollView(fillsViewport: values.count > 8) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(values) { initiative in
                            VStack(spacing: 8) {
                                if initiative.id == dividerID { Divider() }
                                LinearInitiativeCard(initiative: initiative) {
                                    LinearInitiativeProjects(initiative: initiative) { nav.showFocus() }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func issueCard(_ issue: LinearIssueSummary, nested: Bool = false) -> some View {
        LinearIssueEntityRow(issue: issue, nested: nested) {
            nav.showFocus()
        }
    }
}

/// Keep each actual workflow status separate, including custom statuses from different teams.
struct LinearIssueStatusSection: Identifiable {
    var state: LinearWorkflowState
    var issues: [LinearIssueSummary]
    var id: String { state.id }

    static func sections(_ issues: [LinearIssueSummary]) -> [Self] {
        let grouped = Dictionary(grouping: issues) { issue in
            issue.stateId ?? "missing:\(issue.teamID ?? ""):\(issue.stateType ?? ""):\(issue.stateName ?? "")"
        }
        let sections = grouped.map { id, values in
            let issue = values[0]
            return Self(state: LinearWorkflowState(id: id, name: issue.stateName ?? "",
                type: issue.stateType ?? "",
                position: issue.teamStates.first { $0.id == issue.stateId }?.position),
                issues: LinearClient.sortedByPriority(values))
        }
        return sections.sorted { a, b in
            let left = LinearClient.workflowTypeRank(a.state.type), right = LinearClient.workflowTypeRank(b.state.type)
            if left != right { return left < right }
            if let ap = a.state.position, let bp = b.state.position, ap != bp { return ap < bp }
            let order = a.state.name.localizedStandardCompare(b.state.name)
            if order != .orderedSame { return order == .orderedAscending }
            return a.id < b.id
        }
    }
}

@MainActor
struct LinearContainerIssuesView: View {
    let issues: [LinearIssueSummary]
    var nested = false
    var includesClosed = false
    var initiallyMinimized = false
    let onPin: () -> Void
    @Environment(CompanionStore.self) private var companion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collapsedStatusIDs: Set<String> = []

    var body: some View {
        let sections = LinearIssueStatusSection.sections(issues)
        VStack(alignment: .leading, spacing: 0) {
            if issues.isEmpty {
                Text(includesClosed ? companion.l.linearProjectEmptyIssues : companion.l.linearContainerEmptyIssues)
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
            }
            ForEach(sections) { section in
                let collapsed = collapsedStatusIDs.contains(section.id)
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) {
                        if collapsed { collapsedStatusIDs.remove(section.id) }
                        else { collapsedStatusIDs.insert(section.id) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.system(size: 9, weight: .semibold))
                            .frame(width: 10)
                        if let first = section.issues.first { LinearCardStatusIcon(issue: first) }
                        Text(section.state.name.isEmpty ? companion.l.linearStatusUnknown : section.state.name)
                        if sections.filter({ $0.state.name == section.state.name }).count > 1,
                           let team = section.issues.first?.teamKey { Text(team).foregroundStyle(.tertiary) }
                        Text("\(section.issues.count)").foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.top, 10).padding(.bottom, 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityValue(collapsed ? "Collapsed" : "Expanded")
                if !collapsed { rows(section.issues) }
            }
        }
    }

    private func rows(_ values: [LinearIssueSummary]) -> some View {
        ForEach(values) { issue in
            LinearIssueEntityRow(issue: issue, nested: nested, initiallyMinimized: initiallyMinimized, onPin: onPin)
                .padding(.vertical, 4)
        }
    }
}

/// Shared Linear board-style card; the card opens details while each control keeps its own action.
@MainActor
struct LinearIssueEntityRow: View {
    let issue: LinearIssueSummary
    var nested: Bool = false
    let onPin: () -> Void

    @AppStorage("linearIssueCardAllMetadata") private var allMetadata = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var expanded = false
    @State private var minimized = false

    init(issue: LinearIssueSummary, nested: Bool = false, initiallyMinimized: Bool = false,
         onPin: @escaping () -> Void) {
        self.issue = issue
        self.nested = nested
        self.onPin = onPin
        _minimized = State(initialValue: initiallyMinimized)
    }

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL,
                                        style: .system(size: 12), padded: false)
                    Spacer(minLength: 4)
                    LinearFocusButton(issue: issue, durationMenu: true, openDeskOnPin: false, onPinned: onPin)
                    LinearCardAssignee(issue: issue)
                }
                .frame(minHeight: 18)

                HStack(alignment: .top, spacing: 6) {
                    LinearIssueStatusPicker(issue: issue, iconOnly: true)
                    Text(issue.title)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(expanded && !minimized ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                    LinearCardMinimizeButton(minimized: $minimized)
                }
            }

            if !minimized {
                LinearCardMetadata(issue: issue, allMetadata: allMetadata || expanded)

                if (allMetadata || expanded), issue.createdAt != nil || issue.updatedAt != nil {
                    LinearCardDates(issue: issue).allowsHitTesting(false)
                }

                if expanded {
                    Divider().padding(.vertical, 2)
                    if let text = issue.descriptionText, !text.isEmpty {
                        LinearMarkdownText(source: text)
                    }
                    LinearIssueCompletionStats(issue: issue)
                        .allowsHitTesting(false)
                    HStack {
                        Spacer()
                        LinearFocusButton(issue: issue, openDeskOnPin: false, onPinned: onPin)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) {
                    if minimized { minimized = false } else { expanded.toggle() }
                }
            } label: {
                rowShape
                    .fill(colorScheme == .dark
                          ? Color(red: 0.15, green: 0.155, blue: 0.16)
                          : Color(nsColor: .controlBackgroundColor))
                    .overlay { rowShape.fill(Color.primary.opacity(hovering || (expanded && !minimized) ? 0.025 : 0)) }
                    .overlay {
                        rowShape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.35 : 0.045), lineWidth: 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(rowShape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(issue.title)
            .accessibilityValue(minimized ? "Minimized" : (expanded ? "Expanded" : "Collapsed"))
        }
        .contentShape(rowShape)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(expanded && !minimized ? .isSelected : [])
    }
}
