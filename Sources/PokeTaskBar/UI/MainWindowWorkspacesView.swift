import AppKit
import SwiftUI

@MainActor
struct MainWindowWorkspacesView: View {
    let page: MainWindowPage
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(MainWindowNavigation.self) private var nav
    @AppStorage("mainWindowProjectsGrid") private var projectGrid = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var l: L { companion.l }
    private var secondary: Bool { nav.workspaceSecondaryTabs[page] ?? false }
    private var query: String { nav.workspaceQueries[page] ?? "" }
    private var projectStatuses: [LinearWorkflowState] {
        LinearProjectStatuses.options(projects: store.linearProjects, catalog: store.linearProjectStatuses)
    }
    private var projects: [LinearProjectSummary] {
        LinearContainerOrder.pinnedFirst(nav.projectSort.sorted(LinearProjectStatuses.matching(
            store.linearProjects, selection: nav.projectStatus, catalog: store.linearProjectStatuses)
            .filter { matches($0.name) }), ids: store.pinnedLinearProjectIDs)
    }
    private var initiatives: [LinearInitiativeSummary] {
        LinearContainerOrder.pinnedFirst(nav.initiativeSort.sorted(store.linearInitiatives.filter { initiative in
            (secondary ? LinearClient.matchesInitiativePlanned(name: initiative.statusName)
             : LinearClient.matchesInitiativeActive(name: initiative.statusName)) && matches(initiative.name)
        }), ids: store.pinnedLinearInitiativeIDs)
    }
    private var issues: [LinearIssueSummary] {
        let source = nav.issuesTab.issues(in: store, projectID: nav.projectFilter)
        return (nav.issueSorts[nav.issuesTab] ?? .priority).sorted(
            source.filter { matches($0.title + " " + $0.identifier) })
    }
    private func matches(_ text: String) -> Bool { query.isEmpty || text.localizedCaseInsensitiveContains(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { tabs.fixedSize(); Spacer(); actions }
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) { tabs.fixedSize() }
                        .fixedSize(horizontal: false, vertical: true)
                    actions
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search \(page.title(l).lowercased())…", text: Binding(
                    get: { query }, set: { nav.workspaceQueries[page] = $0 }))
                    .textFieldStyle(.plain)
                Spacer()
                if let updated = store.linearIssuesUpdatedAt {
                    RelativeTimestampText(date: updated).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .mainWindowBorder(cornerRadius: 7)
            if page == .issues, let filter = nav.projectFilter,
               let project = store.linearProjects.first(where: { $0.id == filter }) {
                HStack {
                    Label(project.name, systemImage: "folder").font(.system(size: 12))
                    Button("Clear") { nav.projectFilter = nil }.buttonStyle(.link)
                }
            }
            if !store.linearIntegrationEnabled || !store.linearAPIKeyConfigured {
                VStack(alignment: .leading, spacing: 14) {
                    Text(l.linearIssuesNeedsSetup).foregroundStyle(.secondary)
                    Button(l.settings) { nav.select(.settings) }.tahoeButtonStyle(.regular)
                }.mainWindowCard()
            } else {
                if store.linearIssuesError != nil { Text(l.linearIssuesSyncFailed).foregroundStyle(.orange) }
                ScrollView {
                    switch page {
                    case .issues: issueList(issues, emptyText: nav.issuesTab.emptyText(l))
                    case .projects: projectContent
                    case .initiatives: initiativeContent
                    default: EmptyView()
                    }
                }.scrollIndicators(.hidden).roundedScrollViewport()
                    .scrollPosition(id: Binding(get: { nav.workspaceScrollIDs[page] }, set: { nav.workspaceScrollIDs[page] = $0 }))
                    .contextMenu { viewCommands }
            }
        }
    }
    private var tabs: some View {
        HStack(spacing: 6) {
            if page == .issues {
                ForEach(LinearIssuesTab.allCases, id: \.self) { value in
                    tab(value.title(l), selected: nav.issuesTab == value) { nav.issuesTab = value }
                }
            } else if page == .projects {
                LinearProjectStatusMenu(statuses: projectStatuses, selection: Binding(
                    get: { nav.projectStatus }, set: { nav.projectStatus = $0 }))
            } else {
                LinearInitiativeStatusMenu(planned: Binding(
                    get: { secondary }, set: { nav.workspaceSecondaryTabs[page] = $0 }))
            }
        }
    }
    private var actions: some View {
        HStack(spacing: 12) {
            if page == .projects || page == .initiatives {
                LinearProjectIssueFilterMenu()
                if page == .projects {
                    LinearProjectSortMenu(selection: Binding(get: { nav.projectSort }, set: { nav.projectSort = $0 }))
                } else {
                    LinearInitiativeSortMenu(selection: Binding(get: { nav.initiativeSort }, set: { nav.initiativeSort = $0 }))
                }
            } else {
                LinearCardDisplayMenu()
            }
            if page == .issues {
                LinearIssueSortMenu(selection: Binding(
                    get: { nav.issueSorts[nav.issuesTab] ?? .priority },
                    set: { nav.issueSorts[nav.issuesTab] = $0 }))
                NewLinearIssueButton(showsTitle: true)
            }
            if page == .projects {
                TahoeTabBar(selection: $projectGrid,
                    items: [TahoeTabItem(false, title: "List"), TahoeTabItem(true, title: "Grid")])
                    .frame(width: 140)
            }
            Button { Task { _ = await store.refreshLinearIssues() } } label: {
                Image(systemName: "arrow.clockwise")
            }.buttonStyle(.plain).help(l.refreshNow)
                .disabled(store.isRefreshingLinearIssues || !store.linearAPIKeyConfigured)
                .proximityUtility()
        }
    }
    private func tab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 13, weight: selected ? .medium : .regular))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.primary.opacity(selected ? 0.065 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .mainWindowBorder(cornerRadius: 7)
        }.buttonStyle(.plain)
    }
    private func issueList(_ values: [LinearIssueSummary], emptyText: String? = nil) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if values.isEmpty { Text(query.isEmpty ? (emptyText ?? l.linearContainerEmptyIssues) : "No matching issues.")
                .foregroundStyle(.secondary).padding(.vertical, 24) }
            ForEach(LinearIssueHierarchy.roots(values, in: values)) { issue in
                LinearIssueEntityRow(issue: issue, minimization: Binding(
                    get: { nav.issueMinimization[issue.id] ?? false }, set: { nav.issueMinimization[issue.id] = $0 }),
                    expansion: Binding(get: { nav.issueExpansion[issue.id] ?? false }, set: { nav.issueExpansion[issue.id] = $0 }),
                    issuesTab: nav.issuesTab) { nav.select(.focus) }
            }
        }.scrollTargetLayout()
    }
    @ViewBuilder private var projectContent: some View {
        let values = projects
        let dividerID = LinearContainerOrder.dividerID(values, ids: store.pinnedLinearProjectIDs)
        if values.isEmpty { Text(l.linearProjectsNoMatches).foregroundStyle(.secondary).padding(.vertical, 24) }
        if projectGrid {
            VStack(spacing: 12) {
                let pinned = values.filter { store.pinnedLinearProjectIDs.contains($0.id) }
                if !pinned.isEmpty { projectGridGroup(pinned) }
                if dividerID != nil { Divider() }
                projectGridGroup(values.filter { !store.pinnedLinearProjectIDs.contains($0.id) })
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(values) { project in
                    VStack(spacing: 12) {
                        if project.id == dividerID { Divider() }
                        projectCard(project)
                    }.id(project.id)
                }
            }.scrollTargetLayout()
        }
    }
    private func projectGridGroup(_ values: [LinearProjectSummary]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], spacing: 12) {
            ForEach(values) { project in projectCard(project) }
        }.scrollTargetLayout()
    }
    private func projectCard(_ project: LinearProjectSummary) -> some View {
        LinearProjectCard(project: project, hiddenIssueStatuses: store.hiddenLinearIssueStatuses,
                          onViewIssues: { nav.showProjectIssues(project) },
                          expansion: Binding(get: { nav.projectExpansion[project.id] ?? false },
                                             set: { nav.projectExpansion[project.id] = $0 })) {
            nav.select(.focus)
        }
    }
    @ViewBuilder private var viewCommands: some View {
        Button("Fold all") { foldAll(true) }
        Button("Unfold all") { foldAll(false) }
        if page == .projects {
            Picker("Sort", selection: Binding(get: { nav.projectSort }, set: { nav.projectSort = $0 })) {
                ForEach(LinearProjectSort.allCases, id: \.self) { Text($0.title(l)).tag($0) }
            }
            Picker("View", selection: $projectGrid) { Text("List").tag(false); Text("Grid").tag(true) }
        } else if page == .issues {
            Picker("Sort", selection: Binding(get: { nav.issueSorts[nav.issuesTab] ?? .priority },
                set: { nav.issueSorts[nav.issuesTab] = $0 })) {
                ForEach(LinearIssueSort.allCases, id: \.self) { Text($0.title(l)).tag($0) }
            }
        }
        Divider()
        Button(store.todayDeskLayout.rightCollapsed ? "Show side panel" : "Hide side panel") {
            store.todayDeskLayout = store.todayDeskLayout.togglingRight()
        }
    }
    private func foldAll(_ folded: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
            if page == .projects { for project in projects { nav.projectExpansion[project.id] = !folded } }
            else { for issue in store.allLinearIssues {
                nav.issueMinimization[issue.id] = folded
                nav.issueExpansion[issue.id] = !folded
            } }
        }
    }
    @ViewBuilder private var initiativeContent: some View {
        let values = initiatives
        let dividerID = LinearContainerOrder.dividerID(values, ids: store.pinnedLinearInitiativeIDs)
        if values.isEmpty { Text("No matching initiatives.").foregroundStyle(.secondary).padding(.vertical, 24) }
        VStack(spacing: 12) {
            ForEach(values) { initiative in
                VStack(spacing: 12) {
                    if initiative.id == dividerID { Divider() }
                    LinearInitiativeCard(initiative: initiative,
                                         initiallyExpanded: initiative.id == values.first?.id) {
                        initiativeProjects(initiative)
                    }
                }
            }
        }
    }
    private func initiativeProjects(_ initiative: LinearInitiativeSummary) -> some View {
        LinearInitiativeProjects(initiative: initiative, onViewProject: { nav.showProjectIssues($0) }) { nav.select(.focus) }
    }
}
