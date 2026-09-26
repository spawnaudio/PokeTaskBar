import SwiftUI

enum LinearIssueSort: CaseIterable {
    case priority, dueDate, updated, created, title

    func title(_ l: L) -> String {
        switch self {
        case .priority: l.linearSortPriority
        case .dueDate: l.linearSortDueDate
        case .updated: l.linearSortUpdated
        case .created: l.linearSortCreated
        case .title: l.linearSortTitle
        }
    }

    func sorted(_ issues: [LinearIssueSummary]) -> [LinearIssueSummary] {
        if self == .priority { return LinearClient.sortedByPriority(issues) }
        return issues.sorted { a, b in
            switch self {
            case .priority: break
            case .dueDate:
                let left = a.dueDate ?? .distantFuture, right = b.dueDate ?? .distantFuture
                if left != right { return left < right }
            case .updated:
                let left = a.updatedAt ?? .distantPast, right = b.updatedAt ?? .distantPast
                if left != right { return left > right }
            case .created:
                let left = a.createdAt ?? .distantPast, right = b.createdAt ?? .distantPast
                if left != right { return left > right }
            case .title:
                let order = a.title.localizedStandardCompare(b.title)
                if order != .orderedSame { return order == .orderedAscending }
            }
            return a.identifier.localizedStandardCompare(b.identifier) == .orderedAscending
        }
    }
}

@MainActor
struct LinearIssueSortMenu: View {
    @Binding var selection: LinearIssueSort
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        let l = companion.l
        Menu {
            Picker(l.linearSortIssues, selection: $selection) {
                ForEach(LinearIssueSort.allCases, id: \.self) { sort in
                    Text(sort.title(l)).tag(sort)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("\(l.linearSortIssues): \(selection.title(l))")
        .accessibilityLabel(l.linearSortIssues)
        .accessibilityValue(selection.title(l))
    }
}
