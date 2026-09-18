import AppKit
import SwiftUI

@MainActor
struct MainWindowWorkspacesView: View {
    let page: MainWindowPage
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(MainWindowNavigation.self) private var nav
    @AppStorage("mainWindowProjectsGrid") private var projectGrid = false
    @AppStorage("mainWindowInitiativesOverview") private var initiativeOverview = false
    private var l: L { companion.l }
    private var secondary: Bool { nav.workspaceSecondaryTabs[page] ?? false }
    private var query: String { nav.workspaceQueries[page] ?? "" }
    private var projects: [LinearProjectSummary] {
        store.linearProjects.filter { project in
            (secondary ? LinearClient.matchesProjectProduction(name: project.statusName, type: project.statusType)
             : LinearClient.matchesProjectInProgressTab(name: project.statusName, type: project.statusType)) && matches(project.name)
        }
    }
    private var initiatives: [LinearInitiativeSummary] {
        store.linearInitiatives.filter { initiative in
            (secondary ? LinearClient.matchesInitiativePlanned(name: initiative.statusName)
             : LinearClient.matchesInitiativeActive(name: initiative.statusName)) && matches(initiative.name)
        }
    }
    private var issues: [LinearIssueSummary] {
        let source: [LinearIssueSummary]
        if let id = nav.projectFilter, let project = store.linearProjects.first(where: { $0.id == id }) {
            source = project.issues.filter { secondary ? $0.stateType?.lowercased() == "completed" : $0.stateType?.lowercased() != "completed" }
        } else { source = secondary ? store.linearCompletedTodayIssues : store.linearInProgressIssues }
        return source.filter { matches($0.title + " " + $0.identifier) }
    }
    private func matches(_ text: String) -> Bool { query.isEmpty || text.localizedCaseInsensitiveContains(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { tabs; Spacer(); actions }
                VStack(alignment: .leading, spacing: 12) { tabs; actions }
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
            }.padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
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
                    case .issues: issueList(issues)
                    case .projects: projectContent
                    case .initiatives: initiativeContent
                    default: EmptyView()
                    }
                }.scrollIndicators(.hidden)
            }
        }
    }
    private var tabs: some View {
        HStack(spacing: 6) {
            tab(page == .initiatives ? l.linearActiveTab : l.linearInProgressTab, selected: !secondary) {
                nav.workspaceSecondaryTabs[page] = false
            }
            tab(page == .initiatives ? l.linearPlannedTab : page == .projects ? l.linearProductionTab : l.linearCompletedTodayTab,
                selected: secondary) { nav.workspaceSecondaryTabs[page] = true }
        }
    }
    private var actions: some View {
        HStack(spacing: 12) {
            if page == .issues { NewLinearIssueButton(showsTitle: true) }
            if page == .projects {
                Picker("View", selection: $projectGrid) {
                    Text("List").tag(false); Text("Grid").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 140)
            }
            if page == .initiatives {
                Picker("View", selection: $initiativeOverview) {
                    Text("Expanded").tag(false); Text("Overview").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 185)
            }
            Button { Task { _ = await store.refreshLinearIssues() } } label: {
                Image(systemName: "arrow.clockwise")
            }.buttonStyle(.plain).help(l.refreshNow)
                .disabled(store.isRefreshingLinearIssues || !store.linearAPIKeyConfigured)
        }
    }
    private func tab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 13, weight: selected ? .medium : .regular))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.primary.opacity(selected ? 0.065 : 0), in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
    }
    private func issueList(_ values: [LinearIssueSummary]) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if values.isEmpty { Text(query.isEmpty ? l.linearContainerEmptyIssues : "No matching issues.")
                .foregroundStyle(.secondary).padding(.vertical, 24) }
            ForEach(values) { issue in
                LinearIssueEntityRow(issue: issue) { nav.select(.focus) }.padding(8)
            }
        }
    }
    @ViewBuilder private var projectContent: some View {
        if projects.isEmpty { Text("No matching projects.").foregroundStyle(.secondary).padding(.vertical, 24) }
        if projectGrid {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                ForEach(projects) { project in projectCard(project) }
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(projects) { project in
                    LinearFoldableRow(row: LinearContainerRow(project: project), openHelp: l.linearOpenProject) {
                        issueList(project.issues).padding(.leading, 22)
                    }.padding(12)
                }
            }
        }
    }
    private func projectCard(_ project: LinearProjectSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(project.name, systemImage: "folder").font(.system(size: 16, weight: .semibold))
            if let purpose = project.descriptionText { Text(purpose).lineLimit(3).foregroundStyle(.secondary) }
            HStack {
                Text(project.statusName ?? project.statusType ?? "")
                Spacer(); Text("\(project.issues.count) issues")
            }.font(.system(size: 12)).foregroundStyle(.secondary)
            if let date = project.targetDate { Text(date, style: .date).font(.system(size: 12)).foregroundStyle(.secondary) }
            Button("View issues") { nav.showProjectIssues(project) }.buttonStyle(.link)
        }.frame(maxWidth: .infinity, alignment: .leading).mainWindowCard()
    }
    @ViewBuilder private var initiativeContent: some View {
        if initiatives.isEmpty { Text("No matching initiatives.").foregroundStyle(.secondary).padding(.vertical, 24) }
        if initiativeOverview {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(initiatives) { initiative in
                    Button { nav.selectedInitiativeID = initiative.id } label: {
                        HStack { Image(systemName: "flag"); Text(initiative.name); Spacer(); Text(initiative.statusName ?? "") }
                            .padding(14).contentShape(Rectangle())
                            .background(.primary.opacity(nav.selectedInitiativeID == initiative.id ? 0.065 : 0), in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                if let selected = initiatives.first(where: { $0.id == nav.selectedInitiativeID }) ?? initiatives.first {
                    initiativeProjects(selected)
                }
            }
        } else {
            VStack(spacing: 12) {
                ForEach(initiatives) { initiative in
                    LinearFoldableRow(row: LinearContainerRow(initiative: initiative), openHelp: l.linearOpenInitiative,
                                      initiallyExpanded: initiative.id == initiatives.first?.id) {
                        initiativeProjects(initiative)
                    }.padding(12)
                }
            }
        }
    }
    private func initiativeProjects(_ initiative: LinearInitiativeSummary) -> some View {
        let projectIDs = Set(initiative.projectIDs)
        let linked = store.linearProjects.filter { projectIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(linked) { project in projectCard(project) }
            if linked.isEmpty {
                Text("Project details are available in Linear.").foregroundStyle(.secondary)
                if let url = initiative.url { Link("Open in Linear", destination: url) }
            }
        }
    }
}
