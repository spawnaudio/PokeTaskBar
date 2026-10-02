import AppKit
import SwiftUI

@MainActor
struct TaskPlanningView: View {
    @Environment(UsageStore.self) private var usage
    @Environment(FocusSessionStore.self) private var focus
    @Environment(MainWindowNavigation.self) private var nav
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var adding: PlanningGroup?
    @State private var dropGroups: Set<PlanningGroup> = []
    @State private var choosingDay = false
    private var plan: TaskPlanningStore { focus.plan }
    private var query: String { nav.workspaceQueries[.today] ?? "" }
    private var issues: [LinearIssueSummary] { TaskPlanningStore.issues(in: usage) }
    private var matching: [LinearIssueSummary] {
        issues.filter { (plan.projectFilter.isEmpty || $0.projectID == plan.projectFilter) &&
            (query.isEmpty || ($0.title + " " + $0.identifier).localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        @Bindable var plan = plan
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack { dayPicker; Spacer(); options }
                VStack(alignment: .leading, spacing: 10) { dayPicker; options }
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search issues…", text: Binding(
                    get: { query }, set: { nav.workspaceQueries[.today] = $0 })).textFieldStyle(.plain)
                if !plan.projectFilter.isEmpty { Button("Clear project") { plan.projectFilter = "" }.buttonStyle(.link) }
                Text(plan.linked ? "Linked moves" : "Personal plan")
                    .font(.system(size: 11)).foregroundStyle(plan.linked ? Color.blue : .secondary).fixedSize()
            }.padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
                .mainWindowBorder(cornerRadius: 7)
            if plan.syncing { Label("Updating Linear…", systemImage: "arrow.triangle.2.circlepath").font(.caption) }
            if let error = plan.syncError {
                HStack {
                    Text(error).font(.caption).foregroundStyle(.orange)
                    if plan.canRetry { Button("Retry") { Task { await plan.retry(usage: usage) } }.disabled(plan.syncing) }
                }
            }
            if let error = plan.storageError ?? focus.storageError { Text(error).font(.caption).foregroundStyle(.orange) }
            if plan.undoMove != nil {
                Button("Undo last move") { Task { await plan.undo(usage: usage) } }.buttonStyle(.link).disabled(plan.syncing)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !earlierToday.isEmpty { carryReview }
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(PlanningGroup.allCases) { group in section(group) }
                    }.padding(.vertical, 2).padding(12).background(.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
                        .mainWindowBorder(cornerRadius: 10)
                    Divider().padding(.vertical, 4)
                    issueTray
                    if !usage.linearIntegrationEnabled || !usage.linearAPIKeyConfigured {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connect Linear to choose issues for your plan.").foregroundStyle(.secondary)
                            Button("Open Settings") { nav.select(.settings) }.buttonStyle(.link)
                            Button("Start a task timer") { nav.select(.focus) }.buttonStyle(.link)
                        }.mainWindowCard()
                    }
                }.padding(.bottom, 8).scrollTargetLayout()
            }.scrollIndicators(.hidden).roundedScrollViewport()
                .scrollPosition(id: Binding(get: { nav.workspaceScrollIDs[.today] }, set: { nav.workspaceScrollIDs[.today] = $0 }))
        }
        .contextMenu { planningCommands }
        .sheet(item: $adding) { group in
            TaskPlanningPicker(group: group, issues: issues.filter { plan.entry($0.id) == nil })
                .frame(width: 540, height: 460)
        }
    }
    private var dayPicker: some View {
        HStack(spacing: 6) {
            Button { shiftDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 26, height: 30) }.help("Previous day")
            Button { choosingDay.toggle() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                    Text(plan.selectedDay.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    Image(systemName: "chevron.down").font(.system(size: 9)).foregroundStyle(.secondary)
                }.font(.system(size: 13, weight: .medium)).padding(.horizontal, 10).frame(height: 32)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7)).mainWindowBorder(cornerRadius: 7)
            }.help("Choose planning date").accessibilityLabel("Choose planning date")
                .accessibilityIdentifier("planning-date")
                .popover(isPresented: $choosingDay) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Planning date").font(.headline)
                        DatePicker("Planning date", selection: Binding(get: { plan.selectedDay }, set: {
                            plan.selectedDay = $0; choosingDay = false
                        }), displayedComponents: .date).datePickerStyle(.graphical).labelsHidden()
                        Button("Today") { plan.selectedDay = Date(); choosingDay = false }.buttonStyle(.link)
                    }.padding(16)
                }
            Button { shiftDay(1) } label: { Image(systemName: "chevron.right").frame(width: 26, height: 30) }.help("Next day")
            if !Calendar.current.isDateInToday(plan.selectedDay) {
                Button("Today") { plan.selectedDay = Date() }.foregroundStyle(.secondary)
            }
        }.buttonStyle(.plain)
    }
    private func shiftDay(_ delta: Int) {
        plan.selectedDay = Calendar.current.date(byAdding: .day, value: delta, to: plan.selectedDay) ?? plan.selectedDay
    }
    private var options: some View {
        HStack(spacing: 12) {
            Menu(plan.projectFilter.isEmpty ? "All projects" : usage.linearProjects.first { $0.id == plan.projectFilter }?.name ?? "Selected project") {
                Button("All projects") { plan.projectFilter = "" }
                ForEach(usage.linearProjects) { project in Button(project.name) { plan.projectFilter = project.id } }
            }.menuStyle(.borderlessButton).fixedSize().frame(maxWidth: 180, alignment: .leading)
            Menu { planningCommands } label: { Image(systemName: "slider.horizontal.3") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Planning options").accessibilityLabel("Planning options")
            Button { Task { _ = await usage.refreshLinearIssues() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).help("Refresh issues").disabled(usage.isRefreshingLinearIssues)
        }
    }
    @ViewBuilder private var planningCommands: some View {
        Button("Fold all") { animate { plan.foldAll(true); nav.planningIssueFolded = Set(PlanningGroup.allCases) } }
        Button("Unfold all") { animate { plan.foldAll(false); nav.planningIssueFolded = [] } }
        Picker("Sort", selection: Binding(get: { plan.sort }, set: { plan.sort = $0 })) {
            ForEach(PlanningSort.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        Divider()
        Toggle("Link explicit moves to Linear status", isOn: Binding(get: { plan.linked }, set: { plan.linked = $0 }))
        Button(usage.todayDeskLayout.rightCollapsed ? "Show timeline" : "Hide timeline") {
            usage.todayDeskLayout = usage.todayDeskLayout.togglingRight()
        }
    }
    private func animate(_ action: () -> Void) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16), action) }
    private func values(_ group: PlanningGroup) -> [LinearIssueSummary] {
        let values = matching.filter { issue in
            guard let entry = plan.entry(issue.id), entry.group == group else { return false }
            return group != .today || entry.day == plan.dayKey
        }
        switch plan.sort {
        case .manual: return values.sorted { (plan.entry($0.id)?.order ?? 0) < (plan.entry($1.id)?.order ?? 0) }
        case .priority: return LinearIssueSort.priority.sorted(values)
        case .title: return values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }
    private func section(_ group: PlanningGroup) -> some View {
        let values = values(group)
        let context = LinearIssueHierarchy.includingAncestors(values, in: usage.allLinearIssues)
        let childScope = Set(context.map(\.id))
        let folded = plan.folded.contains(group) && !dropGroups.contains(group)
        return Section {
            HStack {
                Button { animate { plan.fold(group) } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: folded ? "chevron.right" : "chevron.down").font(.system(size: 10))
                        Text(group.title).fontWeight(.semibold)
                        Text("\(values.count)").foregroundStyle(.secondary).font(.caption)
                        Spacer()
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityValue(folded ? "Folded" : "Unfolded")
                    .accessibilityIdentifier("planning-fold-\(group.rawValue)")
                Button { adding = group } label: { Image(systemName: "plus").frame(width: 26, height: 26) }
                    .buttonStyle(.plain).help("Add to \(group.title)").proximityUtility()
            }.padding(.top, group == .today ? 0 : 12)
            if !folded {
                if values.isEmpty { Text("Choose an issue for \(group.title.lowercased()).").font(.caption).foregroundStyle(.secondary) }
                ForEach(LinearIssueHierarchy.roots(values, in: context)) { issue in
                    LinearIssueEntityRow(issue: issue,
                        minimization: Binding(get: { nav.issueMinimization[issue.id] ?? false }, set: { nav.issueMinimization[issue.id] = $0 }),
                        expansion: Binding(get: { nav.issueExpansion[issue.id] ?? false }, set: { nav.issueExpansion[issue.id] = $0 }),
                        childScope: childScope) { nav.select(.focus) }
                        .dropDestination(for: String.self) { ids, _ in
                            guard let id = ids.first, id != issue.id, let moving = issues.first(where: { $0.id == id }) else { return false }
                            Task {
                                if plan.entry(id)?.group != group || (group == .today && plan.entry(id)?.day != plan.dayKey) {
                                    await plan.move(moving, to: group, usage: usage)
                                }
                                plan.reorder(id, before: issue.id)
                            }; return true
                        }
                    if plan.linked, TaskPlanningStore.stateID(for: group, issue: issue) != issue.stateId {
                        Label("Linear status differs from the plan", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.id(group.rawValue).contentShape(Rectangle())
            .background(.blue.opacity(dropGroups.contains(group) ? 0.07 : 0), in: RoundedRectangle(cornerRadius: 7))
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first, let issue = issues.first(where: { $0.id == id }) else { return false }
                Task { await plan.move(issue, to: group, usage: usage) }; return true
            } isTargeted: { targeted in
                animate { if targeted { dropGroups.insert(group) } else { dropGroups.remove(group) } }
            }
    }
    private var issueTray: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Issues").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("Drag into a group or onto the timeline").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(PlanningGroup.allCases) { group in issueStatusSection(group) }
        }.padding(.bottom, 2).id("planning-issue-tray")
    }
    private func issueStatusSection(_ group: PlanningGroup) -> some View {
        let available = LinearClient.sortedByPriority(matching.filter { plan.entry($0.id) == nil && group.matchesStatus($0) })
        let context = LinearIssueHierarchy.includingAncestors(available, in: usage.allLinearIssues)
        let childScope = Set(context.map(\.id))
        let folded = nav.planningIssueFolded.contains(group)
        return Section {
            Button {
                animate {
                    if folded { nav.planningIssueFolded.remove(group) } else { nav.planningIssueFolded.insert(group) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: folded ? "chevron.right" : "chevron.down").font(.system(size: 10))
                    Text(group.statusName).fontWeight(.semibold)
                    Text("\(available.count)").foregroundStyle(.secondary).font(.caption)
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(folded ? "Folded" : "Unfolded")
                .accessibilityIdentifier("planning-status-\(group.rawValue)")
                .padding(.top, group == .today ? 10 : 12)
            if !folded {
                if available.isEmpty { Text("No unplanned issues in this status.").font(.caption).foregroundStyle(.secondary) }
                ForEach(LinearIssueHierarchy.roots(available, in: context)) { issue in
                    LinearIssueEntityRow(issue: issue,
                        minimization: Binding(get: { nav.issueMinimization[issue.id] ?? false }, set: { nav.issueMinimization[issue.id] = $0 }),
                        expansion: Binding(get: { nav.issueExpansion[issue.id] ?? false }, set: { nav.issueExpansion[issue.id] = $0 }),
                        childScope: childScope) { nav.select(.focus) }
                }
            }
        }.id("planning-status-\(group.rawValue)")
    }
    private var earlierToday: [LinearIssueSummary] {
        matching.filter { issue in
            guard let entry = plan.entry(issue.id), entry.group == .today, let day = entry.day else { return false }
            return day < plan.dayKey
        }
    }
    private var carryReview: some View {
        DisclosureGroup("Review earlier Today tasks · \(earlierToday.count)") {
            ForEach(earlierToday) { issue in
                HStack {
                    Text(issue.title).lineLimit(1)
                    Spacer()
                    Menu("Move") { TaskPlanningIssueMenu(issue: issue) }
                }.padding(.vertical, 4)
            }
        }.font(.caption).padding(12).mainWindowBorder(cornerRadius: 10)
    }
}

@MainActor
struct TaskPlanningIssueMenu: View {
    let issue: LinearIssueSummary
    @Environment(UsageStore.self) private var usage
    @Environment(FocusSessionStore.self) private var focus
    var body: some View {
        ForEach(PlanningGroup.allCases) { group in
            Button("Move to \(group.title)") { Task { await focus.plan.move(issue, to: group, usage: usage) } }
                .disabled(focus.plan.syncing || !TaskPlanningStore.isOpen(issue))
        }
        Menu("Schedule") {
            ForEach([25, 30, 50, 90], id: \.self) { duration in
                Button("\(duration) minutes") {
                    let hour = Calendar.current.component(.hour, from: Date())
                    _ = focus.plan.schedule(issue, start: hour * 60, duration: duration)
                    usage.todayDeskLayout.rightCollapsed = false
                    focus.openPlanning()
                }
            }
        }.disabled(!TaskPlanningStore.isOpen(issue))
        if focus.plan.entry(issue.id) != nil { Button("Remove from plan") { focus.plan.remove(issue.id) } }
        if let entry = focus.plan.entry(issue.id), focus.plan.linked,
           TaskPlanningStore.stateID(for: entry.group, issue: issue) != issue.stateId {
            Text("Planning and Linear status differ")
        }
        if let url = issue.issueURL { Link("Open in Linear", destination: url) }
    }
}

@MainActor
private struct TaskPlanningPicker: View {
    let group: PlanningGroup
    let issues: [LinearIssueSummary]
    @Environment(\.dismiss) private var dismiss
    @Environment(UsageStore.self) private var usage
    @Environment(FocusSessionStore.self) private var focus
    @State private var query = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Add to \(group.title)").font(.title2); Spacer(); Button("Close") { dismiss() } }
            TextField("Find an unplanned issue…", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(issues.filter { query.isEmpty || ($0.title + " " + $0.identifier).localizedCaseInsensitiveContains(query) }) { issue in
                        Button {
                            Task { await focus.plan.move(issue, to: group, usage: usage); dismiss() }
                        } label: {
                            HStack { LinearCardStatusIcon(issue: issue); Text(issue.identifier).foregroundStyle(.secondary); Text(issue.title).lineLimit(2); Spacer() }
                                .padding(10).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(focus.plan.syncing)
                    }
                    if issues.isEmpty { Text("No unplanned issues in the current Linear snapshot.").foregroundStyle(.secondary) }
                }
            }
            Text("Personal planning is the default. Status linking applies only when explicitly enabled.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }
}
