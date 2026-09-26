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
private enum LinearProjectsTab: Hashable {
    case inProgress
    case production
}

@MainActor
private enum LinearInitiativesTab: Hashable {
    case active
    case planned
}

@MainActor
struct LinearIntegrationView: View {
    let store: UsageStore
    @Environment(CompanionStore.self) private var companion
    @Environment(PopoverNavigation.self) private var nav
    @State private var selectedRoot: LinearRootTab = .issues
    @State private var selectedIssuesTab: LinearIssuesTab = .inProgress
    @State private var issueSorts: [LinearIssuesTab: LinearIssueSort] = [:]
    @State private var selectedProjectsTab: LinearProjectsTab = .inProgress
    @State private var selectedInitiativesTab: LinearInitiativesTab = .active

    private var l: L { companion.l }

    private var visibleIssues: [LinearIssueSummary] {
        (issueSorts[selectedIssuesTab] ?? .priority).sorted(selectedIssuesTab.issues(in: store))
    }

    private var visibleProjects: [LinearProjectSummary] {
        store.linearProjects.filter { project in
            switch selectedProjectsTab {
            case .inProgress:
                return LinearClient.matchesProjectInProgressTab(
                    name: project.statusName, type: project.statusType)
            case .production:
                return LinearClient.matchesProjectProduction(
                    name: project.statusName, type: project.statusType)
            }
        }
    }

    private var visibleInitiatives: [LinearInitiativeSummary] {
        store.linearInitiatives.filter { initiative in
            switch selectedInitiativesTab {
            case .active:
                return LinearClient.matchesInitiativeActive(name: initiative.statusName)
            case .planned:
                return LinearClient.matchesInitiativePlanned(name: initiative.statusName)
            }
        }
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
                LinearCardDisplayMenu()
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
                    TahoeTabBar(selection: $selectedProjectsTab, items: [
                        TahoeTabItem(
                            .inProgress, title: l.linearInProgressTab, symbol: LinearChromeSymbol.project,
                            symbolColor: LinearChromeTint.project),
                        TahoeTabItem(.production, title: l.linearProductionTab, symbol: "cube"),
                    ])
                } else if selectedRoot == .initiatives {
                    TahoeTabBar(selection: $selectedInitiativesTab, items: [
                        TahoeTabItem(.active, title: l.linearActiveTab, symbol: LinearChromeSymbol.initiative),
                        TahoeTabItem(.planned, title: l.linearPlannedTab, symbol: "calendar"),
                    ])
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
                    containerList(
                        items: visibleProjects.map { LinearContainerRow(project: $0) },
                        emptyText: selectedProjectsTab == .production
                            ? l.linearProjectsEmptyProduction
                            : l.linearProjectsEmpty,
                        openHelp: l.linearOpenProject)
                case .initiatives:
                    containerList(
                        items: visibleInitiatives.map { LinearContainerRow(initiative: $0) },
                        emptyText: selectedInitiativesTab == .planned
                            ? l.linearInitiativesEmptyPlanned
                            : l.linearInitiativesEmpty,
                        openHelp: l.linearOpenInitiative)
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

    private func containerList(
        items: [LinearContainerRow],
        emptyText: String,
        openHelp: String
    ) -> some View {
        Group {
            if items.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, 4)
            } else {
                ContentFittingScrollView(fillsViewport: items.count > 8) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { row in
                            LinearFoldableRow(row: row, openHelp: openHelp) {
                                LinearContainerIssuesView(issues: row.issues, nested: true) {
                                    nav.showFocus()
                                }
                            }
                            if row.id != items.last?.id {
                                Divider().opacity(0.6)
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

/// Keep planned work visible in both parent surfaces, with the same issue controls.
@MainActor
struct LinearContainerIssuesView: View {
    let issues: [LinearIssueSummary]
    var nested = false
    let onPin: () -> Void
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        let planned = issues.filter(LinearClient.isPlannedIssue)
        let other = issues.filter { !LinearClient.isPlannedIssue($0) }
        VStack(alignment: .leading, spacing: 0) {
            if issues.isEmpty {
                Text(companion.l.linearContainerEmptyIssues)
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
            }
            rows(other)
            if !planned.isEmpty {
                Text("\(companion.l.linearPlannedTab) · \(planned.count)")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.top, 10).padding(.bottom, 4)
                rows(planned)
            }
        }
    }

    private func rows(_ values: [LinearIssueSummary]) -> some View {
        ForEach(values) { issue in
            LinearIssueEntityRow(issue: issue, nested: nested, onPin: onPin)
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
                        .lineLimit(expanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                }
            }

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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) { expanded.toggle() }
            } label: {
                rowShape
                    .fill(colorScheme == .dark
                          ? Color(red: 0.15, green: 0.155, blue: 0.16)
                          : Color(nsColor: .controlBackgroundColor))
                    .overlay { rowShape.fill(Color.primary.opacity(hovering || expanded ? 0.025 : 0)) }
                    .overlay {
                        rowShape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.35 : 0.045), lineWidth: 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(rowShape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(issue.title)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        }
        .contentShape(rowShape)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(expanded ? .isSelected : [])
    }
}

struct LinearContainerRow: Identifiable {
    var id: String
    var name: String
    var url: URL?
    var statusName: String?
    var leadOrOwner: String?
    var targetDate: Date?
    var descriptionText: String?
    var symbol: String
    var symbolTint: Color
    var issues: [LinearIssueSummary]

    init(project: LinearProjectSummary) {
        id = project.id
        name = project.name
        url = project.url
        statusName = project.statusName ?? project.statusType
        leadOrOwner = project.leadName
        targetDate = project.targetDate
        descriptionText = project.descriptionText
        symbol = LinearChromeSymbol.project
        symbolTint = LinearChromeTint.project
        issues = project.issues
    }

    init(initiative: LinearInitiativeSummary) {
        id = initiative.id
        name = initiative.name
        url = initiative.url
        statusName = initiative.statusName
        leadOrOwner = initiative.ownerName
        targetDate = initiative.targetDate
        descriptionText = initiative.descriptionText
        symbol = LinearChromeSymbol.initiative
        symbolTint = .secondary
        issues = initiative.issues
    }
}

/// Unboxed two-line project/initiative row. Click unfolds metadata, markdown, and issues.
@MainActor
struct LinearFoldableRow<Content: View>: View {
    @Environment(CompanionStore.self) private var companion
    let row: LinearContainerRow
    let openHelp: String
    @ViewBuilder let content: () -> Content

    @State private var expanded = false
    @State private var hoveringHeader = false

    init(row: LinearContainerRow, openHelp: String, initiallyExpanded: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.row = row
        self.openHelp = openHelp
        self.content = content
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { expanded.toggle() }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 14)
                        Image(systemName: row.symbol)
                            .font(.caption)
                            .foregroundStyle(row.symbolTint)
                            .frame(width: 14)
                        Text(row.name)
                            .font(LinearRowTypography.topLevel)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let url = row.url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .controlSize(.mini)
                    .help(openHelp)
                }
            }

            if !expanded {
                collapsedMeta
            }

            if expanded {
                expandedMeta
                if let text = row.descriptionText, !text.isEmpty {
                    LinearMarkdownText(source: text)
                }
                content()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            Color.primary.opacity(hoveringHeader || expanded ? 0.06 : 0),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hoveringHeader = $0 }
        .accessibilityAddTraits(expanded ? .isSelected : [])
    }

    @ViewBuilder
    private var collapsedMeta: some View {
        let chips = metaChips
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, text in
                        LinearTagChip(text: text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var expandedMeta: some View {
        let chips = metaChips
        if !chips.isEmpty {
            FlexibleChipWrap(chips: chips)
        }
    }

    private var metaChips: [String] {
        var chips: [String] = []
        if let status = row.statusName, !status.isEmpty { chips.append(status) }
        if let person = row.leadOrOwner, !person.isEmpty { chips.append(person) }
        if let target = row.targetDate {
            chips.append(target.formatted(.dateTime.month(.abbreviated).day()))
        }
        chips.append("\(row.issues.count)")
        let plannedCount = row.issues.filter(LinearClient.isPlannedIssue).count
        if plannedCount > 0 { chips.append("\(companion.l.linearPlannedTab): \(plannedCount)") }
        return chips
    }
}

@MainActor
private struct FlexibleChipWrap: View {
    let chips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(chips.chunked(by: 3).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, text in
                        LinearTagChip(text: text)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private extension Array {
    func chunked(by size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var rows: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let next = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            rows.append(Array(self[index..<next]))
            index = next
        }
        return rows
    }
}
