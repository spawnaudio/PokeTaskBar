import SwiftUI

enum LinearContainerOrder {
    /// Stable sorting preserves the selected order inside the pinned and unpinned groups.
    static func pinnedFirst<Item: Identifiable>(_ items: [Item], ids: Set<String>) -> [Item] where Item.ID == String {
        items.sorted { ids.contains($0.id) && !ids.contains($1.id) }
    }

    static func dividerID<Item: Identifiable>(_ items: [Item], ids: Set<String>) -> String? where Item.ID == String {
        guard items.contains(where: { ids.contains($0.id) }) else { return nil }
        return items.first { !ids.contains($0.id) }?.id
    }
}

@MainActor
struct LinearContainerPinButton: View {
    let isPinned: Bool
    let action: () -> Void
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12)).foregroundStyle(isPinned ? Color.accentColor : .secondary)
                .frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isPinned ? companion.l.linearUnpinFromTop : companion.l.linearPinToTop)
        .accessibilityLabel(isPinned ? companion.l.linearUnpinFromTop : companion.l.linearPinToTop)
    }
}

enum LinearProjectSort: CaseIterable {
    case name, priority, targetDate, startDate, updated, created

    func title(_ l: L) -> String {
        switch self {
        case .name: l.linearProjectSortName
        case .priority: l.linearSortPriority
        case .targetDate: l.linearProjectSortTarget
        case .startDate: l.linearProjectSortStart
        case .updated: l.linearSortUpdated
        case .created: l.linearSortCreated
        }
    }

    func sorted(_ projects: [LinearProjectSummary]) -> [LinearProjectSummary] {
        projects.sorted { a, b in
            switch self {
            case .name: break
            case .priority:
                let left = (a.priority ?? 0) > 0 ? a.priority! : 5
                let right = (b.priority ?? 0) > 0 ? b.priority! : 5
                if left != right { return left < right }
            case .targetDate, .startDate:
                let left = (self == .targetDate ? a.targetDate : a.startDate) ?? .distantFuture
                let right = (self == .targetDate ? b.targetDate : b.startDate) ?? .distantFuture
                if left != right { return left < right }
            case .updated, .created:
                let left = (self == .updated ? a.updatedAt : a.createdAt) ?? .distantPast
                let right = (self == .updated ? b.updatedAt : b.createdAt) ?? .distantPast
                if left != right { return left > right }
            }
            let order = a.name.localizedStandardCompare(b.name)
            return order == .orderedSame ? a.id < b.id : order == .orderedAscending
        }
    }
}

enum LinearProjectStatuses {
    static func key(_ project: LinearProjectSummary, catalog: [LinearWorkflowState]) -> String {
        project.statusID ?? catalog.first { $0.name == project.statusName && $0.type == project.statusType }?.id
            ?? "\(project.statusType ?? ""):\(project.statusName ?? "")"
    }

    static func options(projects: [LinearProjectSummary], catalog: [LinearWorkflowState]) -> [LinearWorkflowState] {
        var options = catalog
        var seen = Set(catalog.map(\.id))
        for project in projects {
            let id = key(project, catalog: catalog)
            if seen.insert(id).inserted {
                options.append(LinearWorkflowState(id: id, name: project.statusName ?? project.statusType ?? "",
                    type: project.statusType ?? "", position: project.statusPosition))
            }
        }
        let order = ["backlog", "planned", "started", "paused", "completed", "canceled"]
        return options.sorted { a, b in
            let left = order.firstIndex(of: a.type) ?? order.count, right = order.firstIndex(of: b.type) ?? order.count
            if left != right { return left < right }
            if let ap = a.position, let bp = b.position, ap != bp { return ap < bp }
            let comparison = a.name.localizedStandardCompare(b.name)
            return comparison == .orderedSame ? a.id < b.id : comparison == .orderedAscending
        }
    }

    static func matching(_ projects: [LinearProjectSummary], selection: String,
                         catalog: [LinearWorkflowState]) -> [LinearProjectSummary] {
        projects.filter { selection.isEmpty || key($0, catalog: catalog) == selection }
    }
}

/// A named status applies across teams; custom statuses within the same category stay distinct.
enum LinearProjectIssueFilter {
    static func key(name: String?, type: String?) -> String {
        "\(type?.lowercased() ?? ""):\(name?.lowercased() ?? "")"
    }

    static func visible(_ issues: [LinearIssueSummary], hiding hidden: Set<String>) -> [LinearIssueSummary] {
        issues.filter { !hidden.contains(key(name: $0.stateName, type: $0.stateType)) }
    }

    static func options(_ projects: [LinearProjectSummary], additionalIssues: [LinearIssueSummary] = []) -> [LinearWorkflowState] {
        var seen = Set<String>()
        let states = (projects.flatMap(\.issues) + additionalIssues).flatMap { issue in
            issue.teamStates + [LinearWorkflowState(id: "", name: issue.stateName ?? "", type: issue.stateType ?? "", position: nil)]
        }.compactMap { state -> LinearWorkflowState? in
            let id = key(name: state.name, type: state.type)
            guard seen.insert(id).inserted else { return nil }
            return LinearWorkflowState(id: id, name: state.name, type: state.type, position: state.position)
        }
        return LinearClient.sortedWorkflowStates(states)
    }
}

@MainActor
struct LinearProjectIssueFilterMenu: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @State private var showing = false

    var body: some View {
        let options = LinearProjectIssueFilter.options(store.linearProjects,
            additionalIssues: store.linearInitiatives.flatMap(\.issues))
        Button { showing.toggle() } label: {
            Label(companion.l.linearIssueFilter, systemImage: store.hiddenLinearIssueStatuses.isEmpty
                  ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .buttonStyle(.plain).fixedSize().help(companion.l.linearIssueFilter)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(companion.l.linearIssueFilter).font(.headline)
                Button(companion.l.linearProjectShowAllStatuses) { store.hiddenLinearIssueStatuses.removeAll() }
                    .buttonStyle(.link).disabled(store.hiddenLinearIssueStatuses.isEmpty)
                Divider()
                if options.isEmpty {
                    Text(companion.l.linearContainerEmptyIssues).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(options) { status in
                                Toggle(status.name.isEmpty ? companion.l.linearStatusUnknown : status.name, isOn: Binding(
                                    get: { !store.hiddenLinearIssueStatuses.contains(status.id) },
                                    set: { shown in
                                        if shown { store.hiddenLinearIssueStatuses.remove(status.id) }
                                        else { store.hiddenLinearIssueStatuses.insert(status.id) }
                                    }))
                                    .toggleStyle(.checkbox).frame(height: 28).lineLimit(1).help(status.name)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: min(CGFloat(options.count) * 28, 300))
                }
            }.padding(16).frame(width: 270)
        }
    }
}

@MainActor
struct LinearProjectStatusMenu: View {
    let statuses: [LinearWorkflowState]
    @Binding var selection: String
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Menu {
            Picker(companion.l.linearProjectsTab, selection: $selection) {
                Text(companion.l.linearProjectAll).tag("")
                ForEach(statuses) { status in
                    Text(status.name.isEmpty ? companion.l.linearStatusUnknown : status.name).tag(status.id)
                }
            }
        } label: {
            Text(statuses.first { $0.id == selection }?.name ?? companion.l.linearProjectAll)
                .lineLimit(1)
        }.menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel(companion.l.linearProjectsTab)
    }
}

@MainActor
struct LinearInitiativeStatusMenu: View {
    @Binding var planned: Bool
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Menu {
            Picker(companion.l.linearInitiativesTab, selection: $planned) {
                Text(companion.l.linearActiveTab).tag(false)
                Text(companion.l.linearPlannedTab).tag(true)
            }
        } label: {
            Text(planned ? companion.l.linearPlannedTab : companion.l.linearActiveTab)
        }.menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel(companion.l.linearInitiativesTab)
    }
}

enum LinearInitiativeSort: CaseIterable {
    case name, priority, targetDate

    func title(_ l: L) -> String {
        switch self {
        case .name: l.linearProjectSortName
        case .priority: l.linearSortPriority
        case .targetDate: l.linearProjectSortTarget
        }
    }

    func sorted(_ initiatives: [LinearInitiativeSummary]) -> [LinearInitiativeSummary] {
        initiatives.sorted { a, b in
            switch self {
            case .name: break
            case .priority:
                let left = (a.priority ?? 0) > 0 ? a.priority! : 5
                let right = (b.priority ?? 0) > 0 ? b.priority! : 5
                if left != right { return left < right }
            case .targetDate:
                let left = a.targetDate ?? .distantFuture, right = b.targetDate ?? .distantFuture
                if left != right { return left < right }
            }
            let order = a.name.localizedStandardCompare(b.name)
            return order == .orderedSame ? a.id < b.id : order == .orderedAscending
        }
    }
}

@MainActor
struct LinearInitiativeSortMenu: View {
    @Binding var selection: LinearInitiativeSort
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Menu {
            Picker(companion.l.linearSortInitiatives, selection: $selection) {
                ForEach(LinearInitiativeSort.allCases, id: \.self) { sort in Text(sort.title(companion.l)).tag(sort) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down").frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .menuIndicator(.hidden).menuStyle(.borderlessButton).fixedSize()
        .help("\(companion.l.linearSortInitiatives): \(selection.title(companion.l))")
        .accessibilityLabel(companion.l.linearSortInitiatives).accessibilityValue(selection.title(companion.l))
    }
}

@MainActor
struct LinearProjectSortMenu: View {
    @Binding var selection: LinearProjectSort
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Menu {
            Picker(companion.l.linearSortProjects, selection: $selection) {
                ForEach(LinearProjectSort.allCases, id: \.self) { sort in Text(sort.title(companion.l)).tag(sort) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down").frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .menuIndicator(.hidden).menuStyle(.borderlessButton).fixedSize()
        .help("\(companion.l.linearSortProjects): \(selection.title(companion.l))")
        .accessibilityLabel(companion.l.linearSortProjects).accessibilityValue(selection.title(companion.l))
    }
}
